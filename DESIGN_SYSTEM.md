# MEGG Fashion App - Design System

## 🎨 Design Philosophy

This app embodies **minimal luxury** — a design approach inspired by high-end fashion brands like Zara, COS, and Arket. The aesthetic is characterized by:

- **Geometric Precision**: Clean lines, perfect spacing, refined proportions
- **Typographic Excellence**: FuturaCyrillicBook font with wide letter spacing
- **Monochromatic Palette**: Black, white, and subtle grays
- **Intentional White Space**: Breathing room that creates sophistication
- **Custom Iconography**: Hand-crafted icons for unique brand identity

---

## 📐 Typography System

### Font Family
**FuturaCyrillicBook** - A geometric sans-serif that conveys:
- Modern elegance
- Timeless sophistication
- Excellent readability across all sizes
- Clean, architectural quality

### Text Hierarchy

| Element | Size | Weight | Letter Spacing | Usage |
|---------|------|--------|----------------|-------|
| Display Large | 56px | Light (300) | 12px | Brand name, hero text |
| Display Medium | 32px | Light (300) | 2px | Large headings |
| Headline | 22px | Regular (400) | 1px | Product titles |
| Title Large | 15px | Medium (500) | 2.5px | Section headers |
| Title Small | 13px | Medium (500) | 1.5-2px | Subsection headers |
| Body Large | 14px | Regular (400) | 0.3px | Product descriptions |
| Body Small | 12px | Regular (400) | 0.5px | Product names, details |
| Label | 10-11px | Regular/Medium | 1.2-2.5px | Buttons, navigation |

### Letter Spacing Strategy
- **Wide spacing (2-12px)**: Headlines, buttons, navigation - creates luxury feel
- **Tight spacing (0.3-1px)**: Body text - improves readability
- All caps text uses wider letter spacing for elegance

---

## 🎯 Custom Iconography

### Icon Design Principles
1. **Minimal Line Weight**: 1.2px stroke for delicate appearance
2. **Geometric Construction**: Based on circles and straight lines
3. **Consistent Sizing**: 20-22px for optimal clarity
4. **Rounded Caps**: Softer, more refined appearance

### Custom Icons
- **Search**: Circle with diagonal line (magnifying glass)
- **Shopping Bag**: Minimal bag silhouette with handle
- **Heart**: Geometric heart for favorites/wardrobe
- **Home**: Simple house outline
- **Explore**: Compass circle with directional indicator

### Why Custom Icons?
- **Brand Uniqueness**: Distinguishes from Material Design
- **Cohesive Aesthetic**: Matches overall minimal design language
- **Refined Details**: Thinner strokes than standard icons
- **Filled States**: Elegant transitions for active states

---

## 📱 App Bar Design

### Aesthetic App Bar Features
- **Fixed Height**: 56px for consistent rhythm
- **Subtle Border**: 0.5px at 8% opacity - barely visible but creates depth
- **Centered Title**: 15px with 3.5px letter spacing
- **Minimal Icons**: 20px custom icons with 20px splash radius
- **No Elevation**: Flat design with subtle border instead of shadow
- **iOS-style Back**: Arrow back iOS (18px) for refined feel

### Benefits Over Material Design
- No distracting elevation/shadow effects
- Cleaner, more sophisticated appearance
- Better alignment with luxury fashion aesthetic
- Subtle border provides gentle separation

---

## 🔘 Navigation System

### Bottom Navigation
**Custom Implementation** instead of Material BottomNavigationBar:
- **Custom Icons**: Filled states on selection
- **Refined Typography**: 10px labels with 1.2px letter spacing
- **Clean Layout**: 60px height with proper spacing
- **Subtle Border**: 0.5px top border at 8% opacity
- **Smooth Transitions**: Icon fills smoothly when selected

### Active States
- Selected: Black icons + black text (weight 500)
- Unselected: Grey[600] icons + grey text (weight 400)
- Icons transform from outline to filled on selection

---

## 🎨 Color System

### Primary Colors
```
Black: #000000 (Primary text, borders, icons)
White: #FFFFFF (Background, contrast elements)
```

### Grayscale
```
Grey 700: rgba(0,0,0,0.70) - Secondary text
Grey 600: rgba(0,0,0,0.60) - Inactive elements
Grey 350: rgba(0,0,0,0.35) - Disabled states
Black @ 15%: rgba(0,0,0,0.15) - Subtle borders
Black @ 8%: rgba(0,0,0,0.08) - Very subtle dividers
```

### Usage Guidelines
- **Pure black** for primary UI elements
- **Grey tones** for hierarchy and deemphasis
- **Transparent overlays** on images (30-70%)
- **White space** as an active design element

---

## 📦 Component Styling

### Category Cards
- **Minimal Letter Badges**: Single letter (W, M, K, S)
- **Light Weight Font**: 24px at 300 weight
- **Subtle Borders**: 15% opacity instead of solid
- **64x64px Size**: Perfect square proportions

### Product Cards
- **No Shadows**: Flat design language
- **Minimal Text**: Product name + price only
- **Tight Layout**: Optimized spacing
- **Grey Background**: Placeholder for images

### Buttons
- **Sharp Corners**: BorderRadius.zero
- **Letter Spacing**: 2.5px for premium feel
- **Height**: 48-52px for touch targets
- **Weight 500**: Medium for buttons
- **No Elevation**: Flat design

### Filter Bar
- **Compact Design**: Minimal padding
- **Small Icons**: 18px for refinement
- **Small Labels**: 10px with wide tracking
- **View Toggle**: Outlined icons (view_agenda, grid_view)

---

## ✨ Micro-Interactions

### Touch Feedback
- **Splash Radius**: 20px (smaller than default 28px)
- **InkWell**: Subtle ripple effects
- **Icon States**: Smooth filled/outline transitions

### Scrolling Behavior
- **No Material Effects**: Removed default Material elevation changes
- **Transparent Surface Tint**: Clean appearance while scrolling
- **Smooth Transitions**: Native scroll physics

---

## 🏗️ Layout Principles

### Spacing System
- **Base Unit**: 4px
- **Small**: 8px
- **Medium**: 12-16px
- **Large**: 20-24px
- **XL**: 32px
- **XXL**: 60px+

### Grid System
- **Horizontal Padding**: 16px standard
- **Product Grid**: 2 columns, 12px gap
- **Aspect Ratio**: 0.65 for product cards (2:3 ratio)

### Visual Rhythm
- Consistent spacing between sections
- Aligned text and elements
- Breathing room around all components

---

## 🎭 Welcome Screen

### Hero Design
- **Large Brand Name**: 56px with 12px letter spacing
- **Divider Line**: 1px white line at 60% opacity
- **Tagline**: 12px with 5px letter spacing
- **Gradient Overlay**: 30% to 70% for text legibility
- **Minimal Buttons**: 52px height with refined styling

### Button Hierarchy
1. **Primary (White)**: Solid fill - main action
2. **Secondary (Outline)**: 1px border - alternative action

---

## 📊 Design Metrics

### App Bar
- Height: 56px
- Icon Size: 20px
- Title Size: 15px
- Border: 0.5px @ 8% opacity

### Bottom Navigation
- Height: 60px
- Icon Size: 22px
- Label Size: 10px
- Spacing: 6px between icon and label

### Product Cards
- Image Aspect: 2:3 (0.65)
- Name Size: 12px
- Price Size: 13px
- Spacing: 8px between elements

### Section Headers
- Font Size: 15px
- Letter Spacing: 2.5px
- Bottom Margin: 20px

---

## 🎯 Brand Differentiation

### vs. Zara
- **Custom Icons**: Unique visual language
- **FuturaCyrillicBook**: Different from Zara's font
- **Wider Letter Spacing**: More spacious feel
- **Refined Borders**: Subtler than Zara's approach

### vs. Material Design
- **No Shadows**: Completely flat
- **Custom Navigation**: Not using Material components
- **Minimal Icons**: Thinner strokes
- **Refined Spacing**: More intentional white space

### vs. COS/Arket
- **Bolder Typography**: Wider letter spacing
- **Custom Iconography**: Unique to MEGG
- **Sharper Corners**: Zero border radius
- **Monochrome Palette**: Pure black and white

---

## 🚀 Implementation Details

### Files Created
```
lib/widgets/aesthetic_app_bar.dart    - Custom app bar component
lib/widgets/custom_icons.dart         - Hand-crafted icon painters
```

### Typography Integration
```yaml
# pubspec.yaml
fonts:
  - family: FuturaCyrillicBook
    fonts:
      - asset: assets/fonts/FuturaCyrillicBook.ttf
```

### Theme Configuration
- Comprehensive TextTheme with all styles
- Custom button themes
- Bottom navigation theme
- App bar theme with custom styling

---

## 💡 Design Rationale

### Why This Approach?

1. **Timeless Design**: Minimal aesthetics age gracefully
2. **Brand Premium**: Elevated perception through refinement
3. **User Focus**: Clean UI doesn't distract from products
4. **Performance**: Flat design renders faster
5. **Consistency**: Systematic approach ensures cohesion
6. **Uniqueness**: Custom elements create brand identity

### Fashion Industry Standards

High-end fashion apps prioritize:
- **Visual Hierarchy**: Products are the hero
- **White Space**: Luxury through restraint
- **Typography**: Font is a key brand element
- **Minimalism**: Remove everything unnecessary
- **Consistency**: Every element feels intentional

---

## 📱 Screen-Specific Design

### Home Screen
- Hero banner: 450px height
- Category grid: 4 items, minimal badges
- Horizontal product scroll: 320px height
- Product grid: 2 columns

### Explore Screen
- Search chips: Bordered, minimal
- Trending cards: 300px width, horizontal scroll
- Collection grid: 2 columns, 0.8 aspect ratio

### Wardrobe Screen
- Empty state: 64px icon, refined messaging
- Grid view: 2 columns, 0.65 aspect ratio
- Item counter: Grey text, subtle
- Clear button: Small, secondary style

### Product Screen
- Image height: 550px
- Size selectors: 60px squares
- Color chips: Variable width with padding
- Bottom bar: Fixed, 54px height

### Listing Screen
- Filter bar: Compact, 10px vertical padding
- Grid toggle: Minimal icons
- Sort options: Small text, wide spacing

---

## 🎨 Future Enhancements

### Potential Additions
- Subtle animations on interactions
- Loading skeleton screens
- Haptic feedback
- Dark mode variant
- Advanced filter UI
- Size guide modal
- Share sheet styling

### Maintaining Design Quality
- Regular design reviews
- Consistent spacing audits
- Typography hierarchy checks
- Icon alignment verification
- Color usage monitoring

---

**Design System Version**: 1.0  
**Last Updated**: October 2025  
**Designer**: Fashion-First Minimalism Approach

