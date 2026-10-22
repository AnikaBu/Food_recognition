from PIL import Image, ImageDraw, ImageFont

def generate_sample_dish():
    # Создаем изображение 600x600 (вид сверху на тарелку)
    img = Image.new("RGB", (600, 600), color=(240, 235, 225))
    draw = ImageDraw.Draw(img)

    # Стол / фон вокруг тарелки (деревянный оттенок)
    draw.rectangle([0, 0, 600, 600], fill=(210, 180, 140))

    # Большая белая тарелка
    draw.ellipse([60, 60, 540, 540], fill=(255, 255, 255), outline=(220, 220, 220), width=6)
    # Внутреннее углубление тарелки
    draw.ellipse([100, 100, 500, 500], fill=(248, 248, 248), outline=(235, 235, 235), width=2)

    # 1. Гречневая каша (коричневая зона слева)
    draw.ellipse([130, 180, 310, 420], fill=(139, 90, 43))
    for x in range(150, 290, 15):
        for y in range(200, 400, 15):
            draw.ellipse([x, y, x+8, y+6], fill=(105, 60, 25))

    # 2. Куриное филе гриль (золотисто-румяная зона справа сверху)
    draw.polygon([(320, 150), (450, 180), (470, 290), (330, 270)], fill=(218, 165, 32))
    # Полоски гриля
    draw.line([(340, 160), (360, 270)], fill=(120, 60, 20), width=4)
    draw.line([(380, 165), (400, 275)], fill=(120, 60, 20), width=4)
    draw.line([(420, 175), (440, 280)], fill=(120, 60, 20), width=4)

    # 3. Свежие огурцы (зеленые кружочки справа снизу)
    cucumbers = [(330, 320), (380, 330), (350, 380), (410, 390), (440, 340)]
    for cx, cy in cucumbers:
        draw.ellipse([cx, cy, cx+55, cy+55], fill=(46, 139, 87), outline=(34, 100, 60), width=3)
        draw.ellipse([cx+8, cy+8, cx+47, cy+47], fill=(144, 238, 144))

    # Подписи
    draw.text((150, 280), "ГРЕЧКА", fill=(255, 255, 255))
    draw.text((350, 210), "КУРИНОЕ ФИЛЕ", fill=(50, 20, 0))
    draw.text((370, 360), "ОГУРЦЫ", fill=(10, 60, 20))

    img.save("sample_dish.jpg", "JPEG", quality=95)
    print("✅ Создано тестовое изображение: sample_dish.jpg")

if __name__ == "__main__":
    generate_sample_dish()
