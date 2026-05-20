# Example Design Reference

This document extracts reusable visual ideas from the `example_design/` folder so we can borrow the strongest parts during the `UI_UX_ENHANCEMENTS` phase without copying the reference blindly.

Source reviewed:
- `example_design/src/styles/*.css`
- `example_design/src/app/screens/*.tsx`
- `example_design/src/app/components/BottomNav.tsx`
- `example_design/src/app/components/CategoryBadge.tsx`

## 1. Overall Visual Direction

The example design has a soft mobile-food-app look with:
- a fresh green primary identity
- very light mint and off-white surfaces
- rounded cards and pill controls everywhere
- strong section separation through cards instead of hard dividers
- friendly, approachable UI with subtle color coding by feature
- compact typography with bold headings and soft secondary text

The mood is:
- clean
- warm
- healthy
- lightweight
- easy to scan

## 2. Core Color Palette

### Primary brand greens
- `#4A9B6F`:
  Main brand color. Used for primary buttons, active states, icons, quantities, headers, and emphasis.
- `#3A8A5F`:
  Darker companion green. Used in the home hero gradient.
- `#5DC48C`:
  Lighter success/progress green. Used in progress-fill gradients.
- `#A8D8BC`:
  Soft mint text/accent on dark green surfaces.

### Backgrounds and surfaces
- `#FAFCFA`:
  Main app background. Slightly warm off-white with a green tint.
- `#FFFFFF`:
  Card and header surface.
- `#F8FFFE`:
  Tinted surface for soft cards, ingredient rows, and highlighted containers.
- `#F3F7F4`:
  Input/search background and soft neutral chip background.
- `#F0F5F2`:
  Borders, sticky bars, dividers, and soft neutral surfaces.
- `#EBF7F1`:
  Light positive background for active pills, retry buttons, and soft CTA surfaces.
- `#EBF5EE`:
  Green-tinted border color for cards and grouped content.
- `#E5EFE8`:
  Muted structural line color.

### Text colors
- `#1A2B22`:
  Main headline/body emphasis color. This is the strongest dark text in the design.
- `#6B8277`:
  Medium-supporting text.
- `#8FA3B1`:
  Muted secondary text, labels, helper text.
- `#B0BEC5`:
  Very light inactive text/icons.
- `#C4D4CB`:
  Placeholder and inactive stroke tone.

### Accent colors by feature
- `#6366F1` with `#EEF2FF`:
  Planning/calendar accent.
- `#F59E0B` with `#FEF3C7`:
  Shopping/accent warning tone.
- `#EC4899` with `#FCE7F3`:
  Favorites accent.
- `#EF4444` with `#FEE2E2`:
  Destructive/delete/error actions.

### Category badge mapping
- Breakfast: `#D97706` on `#FEF3C7`
- Lunch: `#059669` on `#D1FAE5`
- Dinner: `#4F46E5` on `#EDE9FE`
- Dessert: `#DB2777` on `#FCE7F3`
- Snack: `#EA580C` on `#FFEDD5`

## 3. Typography

### Font family
- `Plus Jakarta Sans`

Why it works here:
- rounded but not childish
- modern and mobile-friendly
- good for bold headings and compact UI labels

### Type hierarchy used repeatedly
- `22px / 800`:
  Main page titles and hero headings
- `17px / 700`:
  Sticky form headers and sub-page titles
- `15px / 700` or `16px / 700-800`:
  Section titles and key content blocks
- `13px / 500-700`:
  Primary body text, form fields, list rows
- `12px / 600-700`:
  Chips, helper buttons, supporting UI labels
- `10px-11px / 600-700`:
  Meta information, labels, counts, captions

### Typography style notes
- Headings are bold and dark.
- Secondary copy is consistently muted blue-green.
- Tiny uppercase labels are used for sections, counters, and meal slots.
- Body text is compact but readable because spacing stays generous.

## 4. Shapes and Radius Language

The design is heavily rounded.

Common radii:
- `rounded-full`:
  Avatars, icon buttons, toggles, completion circles
- `rounded-xl`:
  Small chips, search bars, small action buttons
- `rounded-2xl`:
  Default card shape, list rows, inputs, primary buttons
- `rounded-3xl`:
  Featured card shapes like the home “today’s meals” block
- `24px top corners only`:
  Bottom sheet and lifted content panel patterns

Design takeaway:
- use rounded geometry as a system, not randomly
- reserve the biggest radius for hero cards and important surfaces
- keep forms, cards, and chips visually related through similar curves

## 5. Spacing and Density

Recurring spacing rhythm:
- `16px` page padding is the baseline
- `12px` and `8px` are used inside cards and between compact rows
- `20px-24px` separates major sections
- `3px-4px` is used for tiny supporting spacing in metadata

Density pattern:
- compact content rows
- generous outer spacing
- cards are visually breathable even when content is dense

This is a good fit for our Flutter app because it keeps mobile screens feeling organized without looking empty.

## 6. Surface and Elevation Patterns

### Card style
Typical card recipe:
- white or pale mint background
- `1px` green-tinted border
- soft shadow, usually low blur and low opacity
- `16px-24px` radius

Examples:
- home feature card uses:
  `background: #fff`
  `border: 1px solid #EBF5EE`
  `box-shadow: 0 4px 24px rgba(74,155,111,0.12)`
- mini cards use smaller shadows like:
  `0 2px 12px rgba(0,0,0,0.07)`

### Header treatment
- white sticky headers with subtle bottom border
- home screen is the exception with a green gradient hero

### Hero treatment
- diagonal green gradient
- translucent stat cards inside hero
- rounded content card overlapping hero from below

This overlap pattern is one of the strongest motifs in the example design.

## 7. Component Patterns Worth Reusing

### A. Hero + lifted card
Best used for:
- dashboard/home
- maybe recipe detail summary

Pattern:
- colored hero band on top
- stats or greeting inside hero
- white card overlapping the hero edge

### B. Soft search bars
Pattern:
- pale filled background
- no hard border
- rounded-xl or rounded-2xl
- leading icon
- muted placeholder

### C. Pill filters and status chips
Pattern:
- inactive pills on pale neutral background
- active pill filled with primary green
- compact text, bold weight

### D. Compact info cards
Pattern:
- icon on top
- bold number/value
- tiny uppercase label

Good for:
- dashboard summary
- recipe metadata
- week statistics

### E. Sectioned lists inside grouped cards
Pattern:
- card container around multiple rows
- subtle row separators
- each row stays simple

Good for:
- shopping sections
- grouped recipe stats
- meal slots

### F. Bottom sticky action area
Pattern:
- sticky white footer
- subtle top border and shadow
- single strong CTA or quick-entry control

### G. Bottom sheet picker
Pattern:
- dimmed backdrop
- rounded top corners
- handle bar
- title row + close button
- embedded search field

This is especially relevant for recipe assignment or picker flows.

### H. Category badges
Pattern:
- colored fill + darker matching text
- tiny emoji/icon + short label
- pill shape

This is useful, but we should likely translate the emoji-driven version into a cleaner app-specific chip style.

## 8. Screen-by-Screen Ideas To Borrow

### Home / Dashboard
Strong ideas:
- green hero header
- summary stats inside translucent mini-cards
- quick-action grid with feature-specific accent colors
- overlap card for “today” content

### Recipes list
Strong ideas:
- prominent page title
- top search bar
- horizontally scrolling category pills
- compact card grid with image-first layout

### Add / Edit recipe
Strong ideas:
- sticky top bar with clear save CTA
- dashed photo upload area
- grouped sections with consistent label style
- ingredient and step editors inside soft rows

### Recipe detail
Strong ideas:
- large hero image
- floating translucent circular actions
- compact metadata cards under title
- ingredient and step sections with strong row rhythm

### Meal planner
Strong ideas:
- horizontal day selector
- selected day with filled state
- tiny meal-indicator dots
- soft meal-slot cards
- bottom-sheet recipe picker

### Shopping list
Strong ideas:
- progress treatment
- clear section labels
- strong row readability for quantity
- sticky add-item area

## 9. Reusable Style Rules For Our Flutter Phase

These are the clearest transferable rules:

1. Use green as the main anchor color, but support it with feature accents instead of making every screen the same shade.
2. Prefer warm off-white backgrounds over flat pure white app canvases.
3. Use white and mint cards to structure content instead of drawing heavy separators everywhere.
4. Keep interaction targets rounded and friendly.
5. Use strong, bold titles with muted support text.
6. Make the primary action obvious on each screen.
7. Use color chips and small labels to reduce scanning effort.
8. Make empty states helpful and visually intentional.
9. Use overlap, sticky bars, and grouped cards to create hierarchy.
10. Keep the UI lively, but not noisy.

## 10. What To Borrow Carefully

These parts are useful, but should be adapted rather than copied directly:

- emoji-heavy labels:
  good for mood, but can feel less polished if overused
- very small text:
  nice visually, but Flutter accessibility may need slightly larger defaults
- strong dependence on inline styles:
  in our app this should become centralized theme tokens and reusable widgets
- pink, violet, and amber accents:
  useful as supporting colors, but should be normalized into our own theme system

## 11. Recommended Flutter Design Tokens To Start From

If we turn this into our own app theme, a strong first pass would be:

- Primary:
  `#4A9B6F`
- Primary dark:
  `#3A8A5F`
- App background:
  `#FAFCFA`
- Surface:
  `#FFFFFF`
- Soft surface:
  `#F8FFFE`
- Soft input:
  `#F3F7F4`
- Border:
  `#EBF5EE`
- Heading text:
  `#1A2B22`
- Secondary text:
  `#8FA3B1`
- Error:
  `#EF4444`
- Radius small:
  `12px`
- Radius medium:
  `16px`
- Radius large:
  `24px`

## 12. Best Elements To Inspire Our UI/UX Phase

If we only carry forward a few things, these should be the priority:

- the green hero + lifted card dashboard structure
- the rounded, soft-card visual system
- the compact but polished search/filter patterns
- strong visual grouping for shopping and meal planning
- bold headers with muted supporting text
- feature accent colors used sparingly for quick scanning

## 13. Suggested Use In The Next Phase

When we start `UI_UX_ENHANCEMENTS_PLAN.md`, this reference should guide:
- theme token creation
- reusable card and section components
- shell/dashboard redesign
- recipe card redesign
- shopping and meal-plan section styling
- empty/loading/error state polish

The goal should be:
- inspired by `example_design`
- but adapted to our real Flutter app structure, data, and constraints
- with a cleaner, more consistent in-app design system than the raw reference
