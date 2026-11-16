# Carnation SVG Asset Generation Templates

When generating placeholder or stylized SVG illustrations for Carnation, follow these canvas specifications so the engine's layout and anchor math work seamlessly.

---

## 1. Character Sprite Template (`assets/characters/<char>_<sprite>.svg`)

- **Canvas `viewBox`**: `0 0 500 1000` (1:2 aspect ratio)
- **Alignment Rules**:
  - Every expression of the same character (`neutral`, `smile`, `away`, `surprised`, etc.) **must keep identical hair/body/clothing coordinates** and only modify the eyebrow, eye, blush, and mouth paths (`y ≈ 270..375`).
  - Ground shadow ellipse sits at `cx="250" cy="965"`.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 1000">
  <!-- Ground shadow -->
  <ellipse cx="250" cy="965" rx="150" ry="24" fill="#171525" opacity=".35"/>
  <!-- Lower body / uniform silhouette -->
  <path d="M160 515q-85 100-90 290l-15 160h125l65-285 55 285h130l-25-200q-5-170-90-250z" fill="#273454"/>
  <!-- Shirt & collar -->
  <path d="M175 530 250 610l78-80 55 75-80 190h-105l-80-190z" fill="#f4efe9"/>
  <!-- Back hair -->
  <path d="M145 215q12-160 120-165 130 4 126 175l-22 190H155z" fill="#30233c"/>
  <!-- Face base -->
  <ellipse cx="250" cy="300" rx="105" ry="135" fill="#f3c8ad"/>
  <!-- Front bangs -->
  <path d="M145 280q5-200 120-200 120 6 130 180-55-60-115-80-65 55-135 60z" fill="#30233c"/>
  <!-- Expression layer (customize eyes, eyebrows, blush, mouth here) -->
  <ellipse cx="195" cy="332" rx="16" ry="8" fill="#ea8f9a" opacity=".45"/>
  <ellipse cx="305" cy="332" rx="16" ry="8" fill="#ea8f9a" opacity=".45"/>
  <path d="M206 305q20-26 42 0M270 305q20-26 42 0" fill="none" stroke="#46304a" stroke-width="9" stroke-linecap="round"/>
  <path d="M230 356q22 24 44 0" fill="none" stroke="#b65d72" stroke-width="7" stroke-linecap="round"/>
  <!-- Lapels & ribbon tie -->
  <path d="M163 510 250 605l-45 90-105-80zM337 510l-87 95 45 90 105-80z" fill="#f4efe9"/>
  <path d="m210 690 40-85 40 85-40 45z" fill="#c95e78"/>
</svg>
```

---

## 2. Scene Background / Event CG Template (`assets/backgrounds/<id>.svg`, `assets/cg/<id>.svg`)

- **Canvas `viewBox`**: `0 0 1600 900` (16:9 widescreen, rendered with `BoxFit.cover`)
- **Design Tip**: Keep primary focal details in the upper 70% (`y: 0..640`) because the translucent Galgame dialogue box overlays the bottom 25% of the viewport.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#12172f"/>
      <stop offset="1" stop-color="#624d77"/>
    </linearGradient>
  </defs>
  <rect width="1600" height="900" fill="url(#sky)"/>
  <!-- Horizon / architecture / lighting layers -->
  <circle cx="1190" cy="180" r="72" fill="#e6d9c3"/>
  <path d="M0 680h1600v220H0z" fill="#111725"/>
</svg>
```
