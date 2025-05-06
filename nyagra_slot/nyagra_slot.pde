import java.util.ArrayList;
import java.util.Collections;
import java.io.FileInputStream;
import java.io.IOException;

int imageWidth = 100;
int imageHeight = 100;
ArrayList<PImage> slotImages;
float[] positions = {0, 0, 0, 0};
boolean[] isSpinning = {true, true, true, true};
float spinSpeed = 8;
int visibleImages = 8;
int[][] reelImagesIndex;

FileInputStream jsDevice;  // ジョイスティックデバイス
byte[] jsData = new byte[8];  // ジョイスティックからのデータ
boolean jsConnected = false;  // ジョイスティック接続状態

void loadSlotImages() {
    slotImages = new ArrayList<PImage>();
    File[] files = listFiles("images");
    for (File file : files) {
        PImage img = loadImage(file.getAbsolutePath());
        img.resize(imageWidth, imageHeight);
        slotImages.add(img);
    }
    println("slotImages.length: " + slotImages.size());
}

void randomizeReelImagesIndex() {
    reelImagesIndex = new int[4][visibleImages * 2];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < visibleImages; j++) {
            reelImagesIndex[i][j] = (int) random(slotImages.size());
        }
        for (int j = 0; j < visibleImages; j++) {
            reelImagesIndex[i][j + visibleImages] = reelImagesIndex[i][j];
        }
    }
}

void setupJoystick() {
    try {
        jsDevice = new FileInputStream("/dev/input/js0");
        jsConnected = true;
        println("ジョイスティック接続成功: /dev/input/js0");
    } catch (IOException e) {
        println("ジョイスティック接続エラー: " + e.getMessage());
        jsConnected = false;
    }
}

void setup() {
    size(800, 600);
    loadSlotImages();
    randomizeReelImagesIndex();
    setupJoystick();
}

void drawHitBar() {
    colorMode(HSB, 360, 100, 100);
    float hue = (frameCount * 5) % 360;
    fill(hue, 60, 95, 220);
    stroke((hue + 180) % 360, 60, 100, 220);
    strokeWeight(3);
    int margin = 80;
    rect(margin, height / 2 - imageHeight / 2, width - margin * 2, imageHeight, 30);
    colorMode(RGB, 255, 255, 255);

}
void draw() {
    background(255);
    
    // ジョイスティックの入力を処理
    if (jsConnected) {
        checkJoystickInput();
    }
    
    drawHitBar();

    for (int i = 0; i < 4; i++) {
        int x = 130 + i * (imageWidth + 50);
        int y = height/2 - (imageHeight * visibleImages)/2;
        
        colorMode(HSB, 360, 100, 100);
        float hue = (frameCount % 360);
        fill(hue, 60, 95, 220);
        stroke((hue + 180) % 360, 60, 100, 220);
        strokeWeight(3);
        rect(x - 5, y - 5, imageWidth + 10, imageHeight * visibleImages + 10, 10);
        colorMode(RGB, 255, 255, 255);
        
        if (isSpinning[i]) {
            positions[i] += spinSpeed;
            if (positions[i] >= visibleImages * imageHeight) {
                positions[i] -= visibleImages * imageHeight;
            }
        }
        
        for (int j = 0; j < visibleImages * 2; j++) {
            float imgY = y + j * imageHeight - positions[i];
            image(slotImages.get(reelImagesIndex[i][j]), x, imgY);
        }
        
        if (!isSpinning[i]) {
            float selectedY = y + imageHeight + height/2 - imageHeight/2;
            noFill();
            colorMode(HSB, 360, 100, 100);
            float rainbowHue = (frameCount * 12) % 360;
            stroke(rainbowHue, 60, 100, 220);
            strokeWeight(5);
            rect(x - 2, selectedY - 2, imageWidth + 4, imageHeight + 4, 5);
            colorMode(RGB, 255, 255, 255);
        }
    }
    
    // 操作説明を表示
    fill(50);
    textSize(16);
    textAlign(CENTER);
    text("キー 1-4 でスロットを停止、SPACEキーで再開", width/2, height - 30);
}

void pressSpin(int reelIndex) {
    isSpinning[reelIndex] = false;
    fixPosition(reelIndex);
}

void keyPressed() {
    if (key == ' ') {
        randomizeReelImagesIndex();
        isSpinning = new boolean[4];
        for (int i = 0; i < 4; i++) {
            isSpinning[i] = true;
        }
        positions = new float[4];
        for (int i = 0; i < 4; i++) {
            positions[i] = 0;
        }
    }
    if (key == '1') {
        pressSpin(0);
    }
    if (key == '2') {
        pressSpin(1);
    }   
    if (key == '3') {
        pressSpin(2);
    }
    if (key == '4') {
        pressSpin(3);
    }
}

void fixPosition(int reelIndex) {
    int index = (int) (positions[reelIndex] - (height / 2) + imageHeight / 2) / (imageHeight);
    println("index: " + index);

    positions[reelIndex] = index * imageHeight + (height / 2) - imageHeight / 2;
}

void checkJoystickInput() {
    try {
        // ノンブロッキングで読み込めるデータがあるか確認
        if (jsDevice.available() >= 8) {
            // 8バイト読み込み
            jsDevice.read(jsData);
            
            // イベントタイプがボタン押下(type=1)の場合
            if (jsData[6] == 1) {
                int buttonNumber = jsData[7] & 0xFF;
                int buttonState = jsData[4] & 0xFF;
                
                // ボタンが押された時のみ処理(buttonState=1)
                if (buttonState == 1) {
                    println("Button pressed: " + buttonNumber);
                    
                    // ボタン0-3で対応するスロットを停止
                    if (buttonNumber >= 0 && buttonNumber < 4) {
                        pressSpin(buttonNumber);
                    }
                    
                    // ボタン9(通常はStartボタン)でリスタート
                    if (buttonNumber == 9) {
                        randomizeReelImagesIndex();
                        isSpinning = new boolean[4];
                        for (int i = 0; i < 4; i++) {
                            isSpinning[i] = true;
                        }
                        positions = new float[4];
                        for (int i = 0; i < 4; i++) {
                            positions[i] = 0;
                        }
                    }
                }
            }
        }
    } catch (IOException e) {
        println("ジョイスティック読み込みエラー: " + e.getMessage());
        jsConnected = false;
    }
}

// アプリケーション終了時にデバイスをクローズ
void exit() {
    if (jsConnected && jsDevice != null) {
        try {
            jsDevice.close();
        } catch (IOException e) {
            println("ジョイスティッククローズエラー: " + e.getMessage());
        }
    }
    super.exit();
}
