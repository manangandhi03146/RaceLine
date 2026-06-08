---
name: MotorcycleTrackShare
description: Track rides. Share the feeling.
colors:
  ember-orange: "#FF6D00"
  void-black: "#181818"
  surface: "#242424"
  surface-raised: "#2F2F2F"
  divider: "#383838"
  text-primary: "#F0F0EE"
  text-secondary: "#8C8C8C"
  text-tertiary: "#737373"
  text-ghost: "#595959"
typography:
  display:
    fontFamily: "SF Pro Display, -apple-system, system-ui"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "SF Pro Rounded, -apple-system, system-ui"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  title:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0.2px"
rounded:
  xs: "10px"
  sm: "12px"
  md: "14px"
  lg: "16px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.ember-orange}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
    padding: "0px 16px"
    height: "52px"
  button-secondary:
    backgroundColor: "rgba(255, 109, 0, 0.12)"
    textColor: "{colors.ember-orange}"
    rounded: "{rounded.md}"
    padding: "0px 16px"
    height: "52px"
  card-surface:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  card-ride:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
---

# Design System: MotorcycleTrackShare

## 1. Overview

**Creative North Star: "The Pit Wall"**

MotorcycleTrackShare is built for the 90 seconds between removing your helmet and walking back to the paddock table. The app has to work fast: legible in sunlight, scannable with gloved hands still coming off, and satisfying to share before the next session starts. It is not a fitness tracker. It is not a dashboard. It is a personal tool that happens to end in a trophy: the share card.

The visual system is dark not as aesthetic posturing but as function. The physical scene that forces the answer: a rider sitting trackside, phone pulled from a jacket pocket, reviewing lap data while ambient light comes from every angle. High contrast dark neutrals with a warm, committed orange accent read clearly there in a way that a light theme never would. The stack is deep: near-black background, two tonal surface levels, and ember orange as the carrying voice of the system. Nothing else.

The anti-references are specific. This is not a racing broadcast interface: no carbon-fiber textures, no helmet-cam overlays, no neon-on-black energy. It is not a SaaS dashboard: no hero-metric card grids, no sidebar navigation, no B2B data density. It is a personal tool with personality, built for creators and sharers, not engineers.

**Key Characteristics:**
- Dark tonal system with three depth levels; no shadows
- Ember orange carries the accent voice at more than decorative levels (committed strategy)
- SF Pro only, leveraging Display/Text optical size variants for hierarchy
- Every screen earns its place by leading toward the share card
- Cards are flat surfaces with tight padding; no nested cards, no stripe decorations
- Glanceable hierarchy: display at 34pt Bold for all section titles

## 2. Colors: The Ember Palette

Two voices: a warm neutral stack and a single committed accent. Every surface is a step in the tonal ladder. Orange is not a highlight; it is the product's personality.

### Primary
- **Ember Orange** (#FF6D00, oklch(65% 0.22 40)): The carrying voice. Used on primary CTA buttons, active navigation indicators, stat values that the rider cares most about (max lean, max speed), icon fills in active states, and the header band on ride cards. A screen should have 3-5 ember elements; more than that degrades the signal.

### Neutral
- **Void Black** (#181818): App background. The floor of every screen.
- **Surface** (#242424): Primary container layer. Cards, sheets, navigation bar background.
- **Surface Raised** (#2F2F2F): Secondary container layer. Photo placeholders, nested controls, dividers between surface elements.
- **Divider** (#383838): Thin separators between list sections. Never used as a decorative element.
- **Text Primary** (#F0F0EE): Body text, labels, all readable copy. Tinted slightly warm; never pure white.
- **Text Secondary** (#8C8C8C): Supporting labels, captions, subheadlines in context. 55% luminance.
- **Text Tertiary** (#737373): Quieter supporting text, timestamps. 45% luminance.
- **Text Ghost** (#595959): Disabled states, placeholder hints. 35% luminance.

### Named Rules

**The Ember Rule.** Ember orange appears on a committed set of elements per screen: the primary action, the active tab, and the stat value the rider cares most about. Not every icon, not every border. Committed does not mean indiscriminate. Count the ember elements on any screen; if you exceed five, remove one.

**The Tonal Stack Rule.** Depth is expressed through lightness steps (#181818 → #242424 → #2F2F2F), not through shadows, blurs, or borders. A card sits on the background because it is lighter, not because it has an outline. Never add a border to a card that already lives on a darker background; the contrast does the work.

## 3. Typography

**Display Font:** SF Pro Display (system default, Bold weight)
**Body Font:** SF Pro Text (system default)
**Special use:** SF Pro Rounded for the app logotype / auth headline only

**Character:** SF Pro is not a compromise. Its optical variants (Display at large sizes, Text at reading sizes) give meaningful range without custom fonts, and its weight breadth from Regular through Black covers every hierarchy step the app needs. The Rounded variant appears only at the auth screen headline to add warmth at the product's introduction point. Elsewhere it would dilute the confident tone.

### Hierarchy
- **Display** (Bold, 34px, leading 1.1, tracking -0.5px): Section page titles ("Garage", "Calendar"). One per screen. No surrounding decoration needed.
- **Headline** (Bold Rounded, 24px, leading 1.2, tracking -0.3px): App logotype / auth screen only. Not reused at feature level.
- **Title** (Semibold, 20px, leading 1.25): Ride names on detail screens. The name of a thing the rider cares about.
- **Body** (Regular or Semibold, 17px, leading 1.4): Primary interface text. Semibold at 17px for button labels, spec lines on bike cards. Regular at 17px for form fields, descriptive content.
- **Label** (Regular, 12-15px, leading 1.3): Subheadline at 15px for secondary context; Caption at 12px for timestamps, metadata. Both in text-secondary or text-tertiary.

### Named Rules

**The One-Size Rule.** Display size (34pt) is used for section titles only: one instance per screen, not repeated or used for decorative headers inside cards. The power of 34pt Bold is its scarcity. Using it twice on the same screen neutralizes both.

## 4. Elevation

This system is flat by design. Shadows do not exist. Elevation is expressed entirely through tonal layering: each step up the surface stack is 6-8 lightness points lighter than the one below it.

The three-stop stack:
- **Floor** (Void Black, #181818): Background. Nothing sits here except the scroll canvas.
- **Raised** (Surface, #242424): Cards, sheets, navigation bars. This is where content lives.
- **Lifted** (Surface Raised, #2F2F2F): Elements inside raised surfaces: photo thumbnails, secondary controls, picker backgrounds.

No element goes above Lifted. Nested cards are prohibited. The `.minimalCard()` modifier lives at the Raised stop; its contents live at the Lifted stop if they need visual separation.

### Named Rules

**The Flat-By-Default Rule.** No `boxShadow`, no `blur`, no `backdropFilter`. If two surfaces need separation, they are at different tonal stops. If one stop of separation is not enough, the layout is wrong.

## 5. Components

### Buttons

Tactile and full-width. Buttons are primary and secondary; no tertiary variant. Both share the same shape to make the hierarchy about color, not geometry.

- **Shape:** Gently curved, continuously rounded corners (14pt radius). Not a pill, not a rectangle.
- **Primary:** Ember orange fill (#FF6D00), white text, SF Pro Semibold 17px, 52pt minimum height, full-width layout.
- **Loading state:** Spinner in white replaces the label text. Button disables.
- **Destructive variant:** Red fill (#FF3B30), white text. Same shape. Never ember orange for destructive actions.
- **Secondary:** Ember orange at 12% opacity background, ember orange text. Used immediately below a primary action when both are needed.
- **Spacing:** 16px internal horizontal padding; stacked buttons use 10-14px between them.

### Cards / Containers

Surfaces, not containers. A card is a background, not a box.

- **MinimalCard:** Surface (#242424) fill, 16pt radius, 16px uniform padding. The default container modifier. Full-width. Never nested inside another card.
- **BikeCard (Garage):** Horizontal layout within MinimalCard geometry. 96x96pt photo thumbnail (xs radius, 10pt) on the left, text stack on the right. Bike title in body-semibold white, spec line in body-regular ember-orange at 85% opacity, date in label text-tertiary.
- **Ride Card (Calendar):** Vertical card with a structural header band, not a stripe. The header is a full-width ember-orange bar (36-48pt tall) carrying the ride name in white semibold. Below it, the surface-colored body carries distance, duration, and date. This is structural color, not decorative.
- **No border on any card.** No outline, no stroke, no `border: 1px solid`. Tonal contrast is the separator.

### Inputs / Fields

Currently using system `.roundedBorder` style unchanged. Custom styling is a future step.

- **Default:** System rounded border. Background adapts to system dark mode.
- **Contextual placement:** Always inside a MinimalCard container on auth screens. Never floating on the background.
- **Error:** Red text label directly below the field. No border color change.

### Navigation (Bottom Bar)

Custom bottom navigation bar sitting in a safeAreaInset. Five tabs: Calendar, Ride, Share, Garage, Settings.

- **Active tab:** Ember orange icon + label.
- **Inactive tab:** Text-ghost (#595959) icon + label.
- **Background:** Surface (#242424) with a hairline divider at top in divider color (#383838).
- **Typography:** Label size (12pt) for tab labels. No all-caps.

### Empty States

Used when a list has no items. Three-part vertical layout: icon, title, message.

- **Icon:** SF Symbol at 44pt semibold, ember orange color.
- **Title:** `.title3.semibold`, white.
- **Message:** `.subheadline`, text-secondary (#8C8C8C). Centered, with horizontal padding.
- **Padding:** 32pt all sides. Never inside a card; sits directly on the background.

### Share Card (Signature Component)

The product's signature output. A full-bleed image with route overlay and stat readout, designed to be posted directly to social media. The background is user-selected photo (fill or fit mode). Stats float over the image in the rider's chosen text color. Route is drawn in a separate stroke color. The card's aesthetic should feel more editorial than utilitarian; this is the "trophy" moment.

The share card intentionally does not follow the app's surface/card system. It is a standalone output, not a UI surface.

## 6. Do's and Don'ts

### Do:
- **Do** use ember orange (#FF6D00) as the committed accent: CTA buttons, active tab, ride stat highlights, and ride card header bands.
- **Do** use tonal layering (#181818 → #242424 → #2F2F2F) as the only depth mechanism. Let lightness do the separation work.
- **Do** use SF Pro Display Bold at 34px for every section title ("Garage", "Calendar", "Settings"). One instance per screen.
- **Do** design the CalendarRideCard with a structural ember header band (36-48pt) carrying the ride name. The band is structural, not decorative.
- **Do** keep the share card as a standalone output aesthetic, separate from the app's UI system.
- **Do** use `.continuous` corner style on all rounded rectangles. Never `.circular` or unspecified.

### Don't:
- **Don't** use a side stripe (border-left or a narrow colored edge on a card, list item, or callout greater than 1px). The 3px ember top stripe on the CalendarRideCard is prohibited; use the full header band instead.
- **Don't** use gradient text (`background-clip: text` with gradient fill). Ember orange is a solid color; its value comes from its opacity control, not color mixing.
- **Don't** use glassmorphism (blur + translucent card). The tonal stack does not use blur.
- **Don't** reference motorsport or racing aesthetics: no carbon-fiber textures, no neon overlays, no helmet-cam color grading, no aggressive angled geometry. This is a personal tool, not a broadcast graphic.
- **Don't** use SaaS dashboard patterns: no hero-metric cards (big number, small label, gradient accent), no sidebar navigation, no identical card grids with icon + heading + paragraph text.
- **Don't** nest a MinimalCard inside another MinimalCard. Nested cards are always wrong.
- **Don't** use pure white (#FFFFFF) or pure black (#000000). Text primary is #F0F0EE; background is #181818.
- **Don't** show more than five ember-orange elements on a single screen. Count them before shipping.
