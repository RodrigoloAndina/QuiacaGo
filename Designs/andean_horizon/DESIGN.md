---
name: Andean Horizon
colors:
  surface: '#f9f9fc'
  surface-dim: '#dadadc'
  surface-bright: '#f9f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f6'
  surface-container: '#eeeef0'
  surface-container-high: '#e8e8ea'
  surface-container-highest: '#e2e2e5'
  on-surface: '#1a1c1e'
  on-surface-variant: '#434653'
  inverse-surface: '#2f3133'
  inverse-on-surface: '#f0f0f3'
  outline: '#737784'
  outline-variant: '#c3c6d5'
  surface-tint: '#2559bd'
  primary: '#00327d'
  on-primary: '#ffffff'
  primary-container: '#0047ab'
  on-primary-container: '#a5bdff'
  inverse-primary: '#b1c5ff'
  secondary: '#9d4221'
  on-secondary: '#ffffff'
  secondary-container: '#fe8c65'
  on-secondary-container: '#742405'
  tertiary: '#3c3625'
  on-tertiary: '#ffffff'
  tertiary-container: '#534d3a'
  on-tertiary-container: '#c7bea6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2ff'
  primary-fixed-dim: '#b1c5ff'
  on-primary-fixed: '#001946'
  on-primary-fixed-variant: '#00419e'
  secondary-fixed: '#ffdbd0'
  secondary-fixed-dim: '#ffb59d'
  on-secondary-fixed: '#390c00'
  on-secondary-fixed-variant: '#7e2c0c'
  tertiary-fixed: '#ece2c9'
  tertiary-fixed-dim: '#cfc6ae'
  on-tertiary-fixed: '#201b0c'
  on-tertiary-fixed-variant: '#4c4634'
  background: '#f9f9fc'
  on-background: '#1a1c1e'
  surface-variant: '#e2e2e5'
typography:
  display:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  margin-mobile: 20px
  margin-desktop: 64px
  gutter: 16px
  container-padding: 24px
---

## Brand & Style
The design system is built on the intersection of modern technology and the raw, rhythmic landscape of the Puna region. The brand personality is "Reliable Presence"—steady like the mountains but fluid like a digital service. It targets a multi-generational audience in La Quiaca, from tech-savvy youth to older residents who require extreme legibility and intuitive paths.

The design style is **High-Contrast Minimalism** with **Tactile Softness**. It avoids cluttered folkloric patterns in favor of a color-driven narrative that evokes the Hill of Seven Colors. The UI uses heavy whitespace to simulate the vastness of the plateau, ensuring the interface feels premium, calm, and hyper-local without appearing dated.

## Colors
The palette is derived from the natural transition of a day in Jujuy. 
- **Primary (Deep Blue):** Used for primary actions, navigation, and brand-critical states. It represents the high-altitude sky and evokes professional trust.
- **Secondary (Terracotta):** Used for highlights, decorative accents, and secondary CTAs. It grounds the digital experience in the physical reality of adobe and earth.
- **Tertiary (Light Sand):** Employed as a subtle background container color to differentiate sections without the harshness of pure white.
- **Semantic States:** These colors are reserved strictly for trip status and system feedback. High saturation ensures these states are glanceable under bright sunlight.

## Typography
Inter is used exclusively to maintain a clean, "utility-first" aesthetic. 
- **Scale:** The system uses a generous type scale to accommodate outdoor usage where glare might be an issue.
- **Weight:** Headlines use Bold (700) and SemiBold (600) to establish a clear hierarchy against the map-heavy interface.
- **Labels:** Small labels use increased letter spacing for maximum legibility on low-end mobile devices common in the region.
- **Mobile optimization:** Headline sizes step down significantly on mobile to ensure address strings and driver names do not wrap awkwardly.

## Layout & Spacing
The layout follows a **Fluid Grid** model with a focus on bottom-heavy mobile interaction (the "thumb zone"). 

- **Mobile:** A 4-column grid with 20px side margins. Bottom sheets are the primary container for contextual info.
- **Desktop/Tablet:** A 12-column grid. Content is centered with a max-width of 1200px.
- **Rhythm:** All spacing is based on a 4px/8px baseline. Large 24px padding is preferred inside cards and modals to create a "premium space" feel.
- **Touch Targets:** Minimum touch target size is 48px, but 56px is preferred for primary transportation actions (e.g., "Request Ride").

## Elevation & Depth
Depth is signaled through **Ambient Shadows** and **Tonal Layering**. 

1. **Surface 0 (Background):** White or Light Gray (#F9FAFB).
2. **Surface 1 (Cards/Sheets):** Pure White with a subtle 1px border (#E5E7EB) and a soft, low-opacity shadow (Color: Primary Blue, Opacity: 4%, Blur: 20px).
3. **Surface 2 (Active Elements):** Elevated components like the "Current Ride" card use a more pronounced shadow with a hint of the Secondary Terracotta to suggest warmth and activity.

Avoid harsh black shadows. Instead, use "Umbra" shadows tinted with the Primary Deep Blue to keep the UI feeling airy and integrated with the "mountain sky" theme.

## Shapes
The shape language is defined by **High Roundedness**, echoing the weathered, smooth stones of mountain paths.

- **Standard Buttons & Inputs:** 0.5rem (8px).
- **Cards & Bottom Sheets:** 1.5rem (24px) for the top corners, creating a soft "nesting" effect for information.
- **Avatars & Status Pips:** Full circle (pill-shaped).
- **Visual Continuity:** Every interactive element must have at least an 8px radius to maintain the approachable, non-aggressive brand character.

## Components
- **Buttons:** Primary buttons use the Deep Blue background with White text. They are large (56px height) to ensure accessibility. Secondary buttons use the Light Sand background with Deep Blue text.
- **Bottom Sheets:** These are the core navigation component. They should have a prominent "handle" bar at the top and utilize a 24px corner radius.
- **Ride Option Cards:** Use a 1px solid border (#E5E7EB) that thickens to 2px Deep Blue when selected.
- **Status Chips:** Small, pill-shaped indicators using the Semantic Palette with 10% opacity backgrounds and 100% opacity text for contrast.
- **Input Fields:** Minimalist with a focus on the active state. When focused, the border color changes to Deep Blue with a soft 4px outer glow.
- **Map Pins:** Custom markers using the Terracotta color for "Pickup" and Deep Blue for "Destination," shaped like simplified mountain peaks.