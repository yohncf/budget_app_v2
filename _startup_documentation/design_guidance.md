# Design Guidance (Material 3)

This document defines the user interface guidelines, the color palette roles, and navigation paradigms for the budget application to ensure a unified and premium user experience across Android and Web platforms.

---

## 1. Material Design 3 Compliance
The application MUST strictly adhere to the [Material Design 3 (M3)](https://m3.material.io/) specification. Key requirements include:
- Use of M3 adaptive component layouts (e.g., Navigation Rail for wider screens/Web, Navigation Bar for compact/mobile viewports).
- Applying state layers (hover, focus, pressed, dragged) built into M3.
- Implementing shape themes (rounded corners for cards, dialogs, sheets, and lists) matching M3 definitions. Ensure corners are rounded to maintain the modern, friendly M3 visual language.
- Providing a small "app bar" by default on all pages (which can be customized or overridden as required).
- Supporting dynamic color principles where possible or anchoring strictly to the brand palette detailed below.

---

## 2. Color Palette & Roles

The color scheme is derived from the custom brand palette. Below are the hex codes and their designated roles within the app:

| Color | Hex Code | Role | Description & Usage |
| :--- | :--- | :--- | :--- |
| **Black Background** | `#030303` | Background (Primary) | Used as the main background color for the entire app. |
| **Dark Grey Card** | `#0E0E0E` | Surface / Card / Active Navigation | Used for cards, dropdowns, navigation containers, dialogs, and active/selected navigation states. |
| **Lime Moss** | `#7DAC20` | Primary Accent / Hover / Graph Primary | Used for Floating Action Buttons (FAB), hover borders/glows, graph primary indicators, active highlights, and clicked effects. |
| **Lavender purple** | `#9272BF` | Graph Secondary | Used for secondary elements/lines on graphs. |
| **Google Blue** | `#4285F4` | FAB Menu / Pills / Accents | Used for Speed Dial menus, transaction tags/pills, and specific category accents. |
| **Cinnabar** | `#EE4D44` | Alerts / Errors / Warnings | Used for error messages, outflow warnings, and negative budget alerts. |

---

## 3. Collapsible Navigation Rail
For medium to large viewports (especially on Web and tablet sizes):
- A **Navigation Rail** must be positioned on the left side of the screen.
- The rail must support a **collapsible state** (toggle button to expand/collapse).
  - *Collapsed State*: Displays only icons for each navigation section.
  - *Expanded State*: Displays both icons and clear text labels.
- Transitions between collapsed and expanded states must be animated smoothly.

---

## 4. Floating Action Button (FAB) with Menu
A Floating Action Button (FAB) must be present in the layout:
- In compact screens, it resides at the bottom-right corner. In wider layouts, it can be integrated below or within the navigation area.
- The FAB must display an expand/collapse menu (commonly referred to as a **Speed Dial** in Flutter).
- Tapping/clicking the FAB opens a menu containing quick actions:
  - **Add Transaction** (Negative/Expense or Positive/Income)
  - **Add Account**
  - **Add Budget**
- The menu must overlay a subtle background dimming layer to keep focus on the action choices.
