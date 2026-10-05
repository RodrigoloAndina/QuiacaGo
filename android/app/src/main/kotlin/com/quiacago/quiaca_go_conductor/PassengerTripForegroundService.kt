package com.quiacago.quiaca_go_conductor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class PassengerTripForegroundService : Service() {
    companion object {
        private const val SYNC_CHANNEL = "passenger_trip_sync"
        private const val EVENT_CHANNEL = "passenger_trip_events"
        private const val SYNC_ID = 4301
        private const val EVENT_ID = 4302
        @Volatile var appInForeground = false
    }

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var supabaseUrl = ""
    private var anonKey = ""
    private var accessToken = ""
    private var refreshToken = ""
    private var passengerId = ""
    private var tripId = ""
    private var lastStatus = ""
    private var scheduled = false

    override fun onCreate() {
        super.onCreate()
        createChannels()
        startForeground(SYNC_ID, syncNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences("passenger-background", Context.MODE_PRIVATE)
        if (intent != null) {
            val editor = prefs.edit()
            listOf("supabaseUrl", "anonKey", "accessToken", "refreshToken", "passengerId", "tripId")
                .forEach { key -> intent.getStringExtra(key)?.let { editor.putString(key, it) } }
            editor.apply()
        }
        supabaseUrl = prefs.getString("supabaseUrl", "") ?: ""
        anonKey = prefs.getString("anonKey", "") ?: ""
        accessToken = prefs.getString("accessToken", "") ?: ""
        refreshToken = prefs.getString("refreshToken", "") ?: ""
        passengerId = prefs.getString("passengerId", "") ?: ""
        tripId = prefs.getString("tripId", "") ?: ""
        if (!scheduled) {
            scheduled = true
            executor.scheduleWithFixedDelay({ pollTrip() }, 0, 7, TimeUnit.SECONDS)
        }
        return START_NOT_STICKY
    }

    private fun pollTrip() {
        if (supabaseUrl.isBlank() || tripId.isBlank() || accessToken.isBlank()) return
        val endpoint = "$supabaseUrl/rest/v1/trips?id=eq.$tripId&passenger_id=eq.$passengerId" +
            "&select=id,status,payment_status,driver_name,vehicle_info"
        var response = get(endpoint)
        if (response.first == HttpURLConnection.HTTP_UNAUTHORIZED && refreshSession()) response = get(endpoint)
        if (response.first !in 200..299) return
        val array = try { JSONArray(response.second ?: "[]") } catch (_: Exception) { return }
        if (array.length() == 0) return
        val trip = array.optJSONObject(0) ?: return
        val status = trip.optString("status")
        if (status != lastStatus) {
            if (lastStatus.isNotBlank() && !appInForeground) showEvent(trip)
            lastStatus = status
        }
        if (status == "completed" || status == "cancelled") stopSelf()
    }

    private fun refreshSession(): Boolean {
        if (refreshToken.isBlank()) return false
        val result = post(
            "$supabaseUrl/auth/v1/token?grant_type=refresh_token",
            JSONObject().put("refresh_token", refreshToken).toString(), null
        )
        if (result.first !in 200..299 || result.second == null) return false
        return try {
            val json = JSONObject(result.second!!)
            accessToken = json.getString("access_token")
            refreshToken = json.optString("refresh_token", refreshToken)
            getSharedPreferences("passenger-background", Context.MODE_PRIVATE).edit()
                .putString("accessToken", accessToken).putString("refreshToken", refreshToken).apply()
            true
        } catch (_: Exception) { false }
    }

    private fun get(endpoint: String): Pair<Int, String?> = request(endpoint, "GET", null, accessToken)
    private fun post(endpoint: String, body: String, bearer: String?): Pair<Int, String?> =
        request(endpoint, "POST", body, bearer)

    private fun request(endpoint: String, method: String, body: String?, bearer: String?): Pair<Int, String?> {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(endpoint).openConnection() as HttpURLConnection
            connection.requestMethod = method
            connection.connectTimeout = 6000
            connection.readTimeout = 6000
            connection.setRequestProperty("apikey", anonKey)
            connection.setRequestProperty("Content-Type", "application/json")
            if (!bearer.isNullOrBlank()) connection.setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            Pair(status, stream?.bufferedReader()?.use { it.readText() })
        } catch (_: Exception) { Pair(-1, null) }
        finally { connection?.disconnect() }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            SYNC_CHANNEL, "Seguimiento del viaje", NotificationManager.IMPORTANCE_LOW
        ))
        manager.createNotificationChannel(NotificationChannel(
            EVENT_CHANNEL, "Cambios del viaje", NotificationManager.IMPORTANCE_HIGH
        ))
    }

    private fun pendingIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun syncNotification() = NotificationCompat.Builder(this, SYNC_CHANNEL)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle("QuiacaGo Pasajero")
        .setContentText("Seguimiento del viaje activo")
        .setContentIntent(pendingIntent()).setOngoing(true).setOnlyAlertOnce(true).build()

    private fun showEvent(trip: JSONObject) {
        val status = trip.optString("status")
        val (title, text) = when (status) {
            "accepted" -> Pair("Taxi asignado", "${trip.optString("driver_name")} va hacia vos")
            "arrived" -> Pair("Tu taxi llegó", "El conductor está en el punto de encuentro")
            "in_progress" -> Pair("Viaje iniciado", "Tu viaje está en curso")
            "awaiting_finish_code" -> Pair("Código de finalización", "Mostrale el código al conductor")
            "payment_pending" -> Pair("Confirmá el pago", "Confirmá en la app cuando entregues el efectivo")
            "completed" -> if (trip.optString("payment_status") == "disputed")
                Pair("Pago informado como pendiente", "Soporte revisará el caso. Abrí la app para ver el detalle")
            else Pair("Viaje finalizado", "Gracias por viajar con QuiacaGo")
            "cancelled" -> Pair("Viaje cancelado", "Abrí la app para consultar el estado")
            else -> Pair("Actualización del viaje", "Abrí QuiacaGo para ver el estado")
        }
        val notification = NotificationCompat.Builder(this, EVENT_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher).setContentTitle(title).setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(pendingIntent()).setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH).build()
        getSystemService(NotificationManager::class.java).notify(EVENT_ID, notification)
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    // Android 15 limits dataSync foreground services. Releasing the service on
    // timeout prevents a killed process from being reported as still active;
    // the Flutter lifecycle starts it again while a trip remains active.
    @androidx.annotation.RequiresApi(35)
    override fun onTimeout(startId: Int) {
        stopSelf(startId)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
