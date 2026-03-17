#!/usr/bin/env python3
"""
Generate a high-resolution Apple-style app icon for DevSummary.
Creates a professional icon similar to Apple's News app - colorful gradients with depth.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter
import random

# Icon sizes needed for macOS app icon
SIZES = [16, 32, 64, 128, 256, 512, 1024]

def create_gradient_background(size, colors, angle=45):
    """Create a gradient background with given colors."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Create gradient stops
    steps = len(colors)

    for y in range(size):
        # Calculate position along gradient (0 to 1)
        pos = y / size

        # Find which color segment we're in
        segment = int(pos * (steps - 1))
        segment = min(segment, steps - 2)

        # Calculate local position within segment
        local_pos = (pos * (steps - 1)) - segment

        # Interpolate colors
        c1 = colors[segment]
        c2 = colors[segment + 1]

        r = int(c1[0] + (c2[0] - c1[0]) * local_pos)
        g = int(c1[1] + (c2[1] - c1[1]) * local_pos)
        b = int(c1[2] + (c2[2] - c1[2]) * local_pos)

        # Apply vignette effect
        center_x, center_y = size / 2, size / 2
        dist = math.sqrt((y - center_y) ** 2)
        max_dist = size / 2
        vignette = 1 - (dist / max_dist) * 0.3

        r = int(r * vignette)
        g = int(g * vignette)
        b = int(b * vignette)

        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    return img

def create_symbol(size):
    """Create the DevSummary symbol - a stylized code/summary icon."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scale factor
    s = size / 100

    # Color - white with slight transparency for depth
    main_color = (255, 255, 255, 255)
    shadow_color = (255, 255, 255, 180)

    # Draw a stylized "D" or document icon with code lines
    # Background rounded rectangle (simulated with circles)
    padding = int(12 * s)
    rect_size = size - padding * 2

    # Main document shape - white rounded rectangle
    corner_radius = int(18 * s)

    # Draw shadow
    shadow_offset = int(3 * s)
    draw.rounded_rectangle(
        [padding + shadow_offset, padding + shadow_offset,
         size - padding + shadow_offset, size - padding + shadow_offset],
        radius=corner_radius,
        fill=(0, 0, 0, 40)
    )

    # Main shape
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=main_color
    )

    # Inner content area
    inner_padding = int(18 * s)
    inner_size = size - inner_padding * 2

    # Draw code/summary lines
    line_height = int(6 * s)
    line_gap = int(8 * s)
    start_y = inner_padding + int(12 * s)

    # Title line (thicker)
    title_height = int(10 * s)
    draw.rounded_rectangle(
        [inner_padding, start_y,
         inner_padding + int(50 * s), start_y + title_height],
        radius=int(3 * s),
        fill=(100, 100, 120, 200)
    )

    # Multiple content lines representing commits/summaries
    colors = [
        (59, 130, 246, 200),  # Blue
        (34, 197, 94, 200),   # Green
        (168, 85, 247, 200),  # Purple
        (251, 146, 60, 200),  # Orange
        (236, 72, 153, 200), # Pink
    ]

    y = start_y + title_height + line_gap
    for i, color in enumerate(colors):
        line_width = inner_size - int(random.randint(10, 40) * s)
        draw.rounded_rectangle(
            [inner_padding, y, inner_padding + line_width, y + line_height],
            radius=int(2 * s),
            fill=color
        )
        y += line_height + line_gap

    # Add a small summary icon in corner (magnifying glass for "summary")
    icon_size = int(20 * s)
    icon_x = size - inner_padding - icon_size - int(5 * s)
    icon_y = size - inner_padding - icon_size - int(5 * s)

    # Circle background for icon
    draw.ellipse(
        [icon_x - int(3*s), icon_y - int(3*s),
         icon_x + icon_size + int(3*s), icon_y + icon_size + int(3*s)],
        fill=(255, 255, 255, 230)
    )

    # Simple magnifying glass
    # Circle part
    circle_radius = int(6 * s)
    draw.ellipse(
        [icon_x + int(4*s), icon_y + int(4*s),
         icon_x + int(16*s), icon_y + int(16*s)],
        outline=(100, 100, 120, 255),
        width=int(2*s)
    )
    # Handle
    draw.line(
        [(icon_x + int(14*s), icon_y + int(14*s)),
         (icon_x + int(20*s), icon_y + int(20*s))],
        fill=(100, 100, 120, 255),
        width=int(2*s)
    )

    return img

def create_icon(size, seed=42):
    """Create a complete icon at the given size."""
    random.seed(seed)

    # Vibrant gradient colors - inspired by Apple's News app
    # Blues, purples, pinks - tech/dev aesthetic
    colors = [
        (30, 64, 175),    # Deep blue
        (79, 70, 229),    # Indigo
        (139, 92, 246),   # Purple
        (217, 70, 239),   # Magenta
        (251, 146, 60),   # Orange accent
    ]

    # Create gradient background
    bg = create_gradient_background(size, colors, angle=45)

    # Create and overlay symbol
    symbol = create_symbol(size)

    # Composite
    result = Image.alpha_composite(bg, symbol)

    return result

def main():
    """Generate all icon sizes and save as icns-compatible format."""
    output_dir = "Assets/AppIcon.iconset"
    os.makedirs(output_dir, exist_ok=True)

    print("Generating app icons...")

    for size in SIZES:
        img = create_icon(size)

        # Save @1x
        filename_1x = f"icon_{size}x{size}.png"
        img.save(os.path.join(output_dir, filename_1x), "PNG")

        # Save @2x
        filename_2x = f"icon_{size}x{size}@2x.png"
        # For 2x, we use 2x the size but save with @2x name
        img_2x = create_icon(size * 2)
        img_2x.save(os.path.join(output_dir, filename_2x), "PNG")

        print(f"  Created {size}x{size} and {size}x{size}@2x")

    # Generate source image for reference
    source = create_icon(1024)
    source.save("Assets/icon_source.png", "PNG")
    print("  Created icon_source.png")

    # Create Contents.json for asset catalog
    contents_json = '''{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
'''
    with open(os.path.join(output_dir, "Contents.json"), "w") as f:
        f.write(contents_json)

    print(f"\n✅ Generated {len(SIZES) * 2} icon images in {output_dir}")
    print("   Use 'iconutil -c icns Assets/AppIcon.iconset' to create .icns file")

if __name__ == "__main__":
    main()
