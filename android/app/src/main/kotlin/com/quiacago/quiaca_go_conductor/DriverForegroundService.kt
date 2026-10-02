package com.quiacago.quiaca_go_conductor

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class DriverForegroundService : Service(), LocationListener {
    companion object {
        private const val CONNECTION_CHANNEL = "driver_connection"
        private const val OFFER_CHANNEL = "trip_offers"
        private const val CONNECTION_NOTIFICATION_ID = 4201
        private const val OFFER_NOTIFICATION_ID = 4202
        @Volatile
        var isActive = false
            private set
        @Volatile
        var appInForeground = false
        @Volatile
        var currentAccessToken = ""
            private set
        @Volatile
        var currentRefreshToken = ""
            private set
    }

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var scheduled = false
    private var locationManager: LocationManager? = null
    private var latestLocation: Location? = null
    private var lastNotifiedTripId: String? = null

    private var supabaseUrl = ""
    private var anonKey = ""
    private var accessToken = ""
    private var refreshToken = ""
    private var driverId = ""
    private var driverName = ""
    private var vehicleInfo = ""
    private var plate = ""

    override fun onCreate() {
        super.onCreate()
        isActive = true
        createNotificationChannels()
        startForeground(CONNECTION_NOTIFICATION_ID, connectionNotification("Preparando conexión…"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) saveArguments(intent)
        loadArguments()
        startForeground(CONNECTION_NOTIFICATION_ID, connectionNotification("Conectado y buscando viajes"))
        startLocationUpdates()
        if (!scheduled) {
            scheduled = true
            executor.scheduleWithFixedDelay({ tick() }, 0, 5, TimeUnit.SECONDS)
        }
        return START_STICKY
    }

    private fun saveArguments(intent: Intent) {
        val editor = getSharedPreferences("driver-background", Context.MODE_PRIVATE).edit()
        listOf(
            "supabaseUrl", "anonKey", "accessToken", "refreshToken", "driverId",
            "driverName", "vehicleInfo", "plate"
        ).forEach { key ->
            intent.getStringExtra(key)?.let { editor.putString(key, it) }
        }
        editor.apply()
    }

    private fun loadArguments() {
        val prefs = getSharedPreferences("driver-background", Context.MODE_PRIVATE)
        supabaseUrl = prefs.getString("supabaseUrl", "") ?: ""
        anonKey = prefs.getString("anonKey", "") ?: ""
        accessToken = prefs.getString("accessToken", "") ?: ""
        refreshToken = prefs.getString("refreshToken", "") ?: ""
        currentAccessToken = accessToken
        currentRefreshToken = refreshToken
        driverId = prefs.getString("driverId", "") ?: ""
        driverName = prefs.getString("driverName", "") ?: ""
        vehicleInfo = prefs.getString("vehicleInfo", "") ?: ""
        plate = prefs.getString("plate", "") ?: ""
    }

    private fun startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let {
                latestLocation = it
            }
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER, 5000L, 3f, this
            )
            locationManager?.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER, 10000L, 5f, this
            )
        } catch (_: Exception) {
            // El polling continúa y volverá a usar la última ubicación disponible.
        }
    }

    override fun onLocationChanged(location: Location) {
        latestLocation = location
    }

    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    private fun tick() {
        if (appInForeground) return
        if (supabaseUrl.isBlank() || anonKey.isBlank() || accessToken.isBlank() || driverId.isBlank()) return
        latestLocation?.let { publishLocation(it) }
        pollOffer()
    }

    private fun publishLocation(location: Location) {
        val body = JSONObject()
            .put("driver_id", driverId)
            .put("driver_name", driverName)
            .put("vehicle_info", vehicleInfo)
            .put("plate", plate)
            .put("latitude", location.latitude)
            .put("longitude", location.longitude)
            .put("is_online", true)
            .put("updated_at", utcNow())
        authorizedRequest(
            "$supabaseUrl/rest/v1/driver_locations?on_conflict=driver_id",
            body.toString(),
            mapOf("Prefer" to "resolution=merge-duplicates")
        )
    }

    private fun pollOffer() {
        val response = authorizedRequest(
            "$supabaseUrl/rest/v1/rpc/get_driver_trip_offer", "{}"
        ) ?: return
        val offer = parseOffer(response) ?: return
        val tripId = offer.optString("id")
        if (tripId.isBlank() || tripId == "null" || tripId == lastNotifiedTripId) return
        lastNotifiedTripId = tripId
        showOfferNotification(offer)
    }

    private fun parseOffer(response: String): JSONObject? {
        val trimmed = response.trim()
        if (trimmed.isBlank() || trimmed == "null" || trimmed == "{}" || trimmed == "[]") return null
        return try {
            if (trimmed.startsWith("[")) {
                val array = JSONArray(trimmed)
                if (array.length() == 0) null else array.optJSONObject(0)
            } else {
                JSONObject(trimmed)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun authorizedRequest(
        endpoint: String,
        body: String,
        additionalHeaders: Map<String, String> = emptyMap()
    ): String? {
        var result = request(endpoint, body, accessToken, additionalHeaders)
        if (result.first == HttpURLConnection.HTTP_UNAUTHORIZED && refreshSession()) {
            result = request(endpoint, body, accessToken, additionalHeaders)
        }
        return if (result.first in 200..299) result.second else null
    }

    private fun refreshSession(): Boolean {
        if (refreshToken.isBlank()) return false
        val endpoint = "$supabaseUrl/auth/v1/token?grant_type=refresh_token"
        val result = request(
            endpoint,
            JSONObject().put("refresh_token", refreshToken).toString(),
            null
        )
        if (result.first !in 200..299 || result.second == null) return false
        return try {
            val json = JSONObject(result.second!!)
            accessToken = json.getString("access_token")
            refreshToken = json.optString("refresh_token", refreshToken)
            currentAccessToken = accessToken
            currentRefreshToken = refreshToken
            getSharedPreferences("driver-background", Context.MODE_PRIVATE).edit()
                .putString("accessToken", accessToken)
                .putString("refreshToken", refreshToken)
                .apply()
            val projectRef = URL(supabaseUrl).host.substringBefore('.')
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putString("flutter.sb-$projectRef-auth-token", result.second)
                .apply()
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun request(
        endpoint: String,
        body: String,
        bearer: String?,
        additionalHeaders: Map<String, String> = emptyMap()
    ): Pair<Int, String?> {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(endpoint).openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 6000
            connection.readTimeout = 6000
            connection.doOutput = true
            connection.setRequestProperty("apikey", anonKey)
            connection.setRequestProperty("Content-Type", "application/json")
            if (!bearer.isNullOrBlank()) connection.setRequestProperty("Authorization", "Bearer $bearer")
            additionalHeaders.forEach { (key, value) -> connection.setRequestProperty(key, value) }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            Pair(status, stream?.bufferedReader()?.use { it.readText() })
        } catch (_: Exception) {
            Pair(-1, null)
        } finally {
            connection?.disconnect()
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CONNECTION_CHANNEL,
                "Conductor conectado",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Mantiene activa la recepción de viajes y la ubicación" }
        )
        manager.createNotificationChannel(
            NotificationChannel(
                OFFER_CHANNEL,
                "Solicitudes de viaje",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Avisa cuando llega una nueva solicitud"
                enableVibration(true)
            }
        )
    }

    private fun appPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun connectionNotification(text: String) = NotificationCompat.Builder(this, CONNECTION_CHANNEL)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle("QuiacaGo Conductor")
        .setContentText(text)
        .setContentIntent(appPendingIntent())
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .build()

    private fun showOfferNotification(offer: JSONObject) {
        val pickup = offer.optString("pickup_address", "Origen indicado")
        val destination = offer.optString("destination_address", "Destino indicado")
        val fare = offer.optDouble("fare_amount", 0.0)
        val text = "$pickup → $destination · \$${fare.toInt()}"
        val notification = NotificationCompat.Builder(this, OFFER_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Nueva solicitud de viaje")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(appPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(OFFER_NOTIFICATION_ID, notification)
    }

    private fun utcNow(): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date())
    }

    override fun onDestroy() {
        isActive = false
        locationManager?.removeUpdates(this)
        executor.shutdownNow()
        scheduled = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
