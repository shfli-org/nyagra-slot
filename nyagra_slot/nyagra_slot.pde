import java.util.ArrayList;
import java.util.Collections;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.File;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.LineUnavailableException;
import javax.sound.sampled.UnsupportedAudioFileException;

int imageWidth = 100;
int imageHeight = 100;
ArrayList<PImage> slotImages;
float[] positions = {0, 0, 0, 0};
boolean[] isSpinning = {true, true, true, true};
int visibleImages = 8;
int[][] reelImagesIndex;
PImage logo;

Clip winSound;
Clip loseSound;

void loadSlotImages() {
    slotImages = new ArrayList<PImage>();
    File[] files = listFiles(sketchPath("images"));
    if (files != null) {
        for (File file : files) {
            PImage img = loadImage(file.getPath());
            if (img != null) {
                img.resize(imageWidth, imageHeight);
                slotImages.add(img);
            } else {
                println("Error loading image: " + file.getPath());
            }
        }
    } else {
        println("No files found in images folder or folder does not exist: " + sketchPath("images"));
    }
    println("slotImages.size(): " + slotImages.size());
    if (slotImages.isEmpty()) {
        println("CRITICAL: No slot images loaded. Slot machine will not work.");
    }
}

void loadAudio() {
    try {
        File winFile = new File(sketchPath("audio/hit.wav"));
        if (winFile.exists()) {
            AudioInputStream audioStreamWin = AudioSystem.getAudioInputStream(winFile);
            winSound = AudioSystem.getClip();
            winSound.open(audioStreamWin);
        } else {
            println("Error: audio/hit.wav not found.");
            winSound = null;
        }
    } catch (UnsupportedAudioFileException | IOException | LineUnavailableException e) {
        println("Error loading audio/hit.wav: " + e.getMessage());
        e.printStackTrace();
        winSound = null;
    }

    try {
        File loseFile = new File(sketchPath("audio/lost.wav"));
        if (loseFile.exists()) {
            AudioInputStream audioStreamLose = AudioSystem.getAudioInputStream(loseFile);
            loseSound = AudioSystem.getClip();
            loseSound.open(audioStreamLose);
        } else {
            println("Error: audio/lost.wav not found.");
            loseSound = null;
        }
    } catch (UnsupportedAudioFileException | IOException | LineUnavailableException e) {
        println("Error loading audio/lost.wav: " + e.getMessage());
        e.printStackTrace();
        loseSound = null;
    }

    if (winSound == null) {
        println("Audio playback for wins will be disabled.");
    }
    if (loseSound == null) {
        println("Audio playback for losses will be disabled.");
    }
}

void randomizeReelImagesIndex() {
    if (slotImages == null || slotImages.isEmpty()) {
        println("Cannot randomize reel images: slotImages is null or empty. Call loadSlotImages() first.");
        return;
    }
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

boolean isSpinningFinished() {
    for (int i = 0; i < 4; i++) {
        if (isSpinning[i]) {
            return false;
        }
    }
    return true;
}

void setup() {
    size(800, 600);
    loadSlotImages();
    randomizeReelImagesIndex();
    loadAudio();
    logo = loadImage("logo.png");
    if (logo == null) {
        println("Error: Could not load logo.png. Logo will not be displayed.");
    }

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

int calcSpinSpeed() {
    int count = 0;
    for (int i = 0; i < 4; i++) {
        if (!isSpinning[i]) {
            count++;
        }
    }
    int spinSpeed = 5 + count * 4;
    return spinSpeed;
}

void draw() {
    background(255);
    int spinSpeed = calcSpinSpeed();
    int[][] currentVisibleIndices = getCurrentMatrixIndex();
    int[][] imageIdMatrix = indexToImageIndex(currentVisibleIndices);
    boolean[][] hit = getHittedMatrix(imageIdMatrix);
    int reelDisplayStripLength = visibleImages * 2;

    for (int i = 0; i < 4; i++) {
        int x = 40 + i * (imageWidth + 50);
        int y_reelVisibleTop = height/2 - (imageHeight * visibleImages)/2;
        
        pushStyle();
        colorMode(HSB, 360, 100, 100);
        float hue = (frameCount % 360);
        fill(hue, 60, 95, 180);
        stroke((hue + 180) % 360, 60, 100, 220);
        strokeWeight(3);
        rect(x - 5, y_reelVisibleTop - 5, imageWidth + 10, imageHeight * visibleImages + 10, 10);
        popStyle();
        
        if (isSpinning[i]) {
            positions[i] += spinSpeed;
            if (positions[i] >= visibleImages * imageHeight) {
                positions[i] -= visibleImages * imageHeight;
            }
        }

        int normalizedHitLineImageIndex = getNormalizedIndexOfImageOnHitline(i);
        
        int[] paylineWindowIndices = new int[5];
        for(int k=0; k<5; k++) {
            paylineWindowIndices[k] = (normalizedHitLineImageIndex + k - 2 + reelDisplayStripLength) % reelDisplayStripLength;
        }

        for (int j = 0; j < reelDisplayStripLength; j++) {
            float imgY = y_reelVisibleTop + j * imageHeight - positions[i];
            
            if (imgY + imageHeight > y_reelVisibleTop && imgY < y_reelVisibleTop + visibleImages * imageHeight) {
                pushStyle();
                boolean isInPaylineWindow = false;
                int paylineSlot = -1;

                for(int k=0; k<5; k++) {
                    if (j == paylineWindowIndices[k]) {
                        isInPaylineWindow = true;
                        paylineSlot = k;
                        break;
                    }
                }

                boolean isActuallyHitImage = isSpinningFinished() && isInPaylineWindow && hit[i][paylineSlot];

                if (isActuallyHitImage) {
                    colorMode(HSB, 360, 100, 100, 255);
                    float rainbowHue = (frameCount * 7 + i * 40 + j * 15) % 360;
                    tint(rainbowHue, 95, 100, 255);
                } else if (isSpinningFinished()) {
                    if (isInPaylineWindow) {
                        tint(255, 80);
                    } else {
                        tint(255, 40);
                    }
                } else {
                    tint(255, 255);
                }
            
                if (slotImages.size() > reelImagesIndex[i][j]) {
                    if (isActuallyHitImage) {
                        pushStyle();
                        colorMode(HSB, 360, 100, 100, 255);
                        float rainbowHue = (frameCount * 7 + i * 40 + j * 15) % 360;
                        stroke(rainbowHue, 95, 100, 255);
                        strokeWeight(6);
                        noFill();
                        rect(x - 4, imgY - 4, imageWidth + 8, imageHeight + 8, 24);
                        popStyle();
                    } else if (isInPaylineWindow) {
                        pushStyle();
                        stroke(180, 100, 100, 80);
                        strokeWeight(2);
                        noFill();
                        rect(x, imgY, imageWidth, imageHeight, 18);
                        popStyle();
                    }
                    int margin = 3;
                    image(slotImages.get(reelImagesIndex[i][j]), x + margin, imgY + margin, imageWidth - margin * 2, imageHeight - margin * 2);
                }
                popStyle();
            }
        }
    }

    drawHitMatrix(hit);
    drawButton();
}

void drawButton() {
    // top
    noStroke();
    fill(255, 0, 0);  // red
    rect(30, -10, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("O", 30 + (imageWidth + 20) / 2 - 4, 20);

    fill(0, 0, 255);  // blue
    rect(30 + 1 * (imageWidth + 50), -10, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("X", 30 + 1 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, 20);

    fill(255, 105, 180);  // hot pink
    rect(30 + 2 * (imageWidth + 50), -10, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(22);  // slightly larger text
    text("[ ]", 30 + 2 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, 20);

    fill(0, 255, 0);  // green
    rect(30 + 3 * (imageWidth + 50), -10, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("△", 30 + 3 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, 20);


    // bottom
    noStroke();
    fill(255, 0, 0);  // red
    rect(30, height - 30, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("O", 30 + (imageWidth + 20) / 2 - 4, height - 10);

    fill(0, 0, 255);  // blue
    rect(30 + 1 * (imageWidth + 50), height - 30, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("X", 30 + 1 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, height - 10);

    fill(255, 105, 180);  // hot pink
    rect(30 + 2 * (imageWidth + 50), height - 30, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(22);  // slightly larger text
    text("[ ]", 30 + 2 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, height - 10);

    fill(0, 255, 0);  // green
    rect(30 + 3 * (imageWidth + 50), height - 30, imageWidth + 20, 40, 30);
    fill(255, 255, 255);  // white text
    textSize(20);
    text("△", 30 + 3 * (imageWidth + 50) + (imageWidth + 20) / 2 - 4, height - 10);
    
}

void drawHitMatrix(boolean[][] hit) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 5; j++) {
            pushStyle();
            if (hit[i][j]) {
                fill(0, 255, 0);
            } else {
                fill(200, 255, 120);
            }
            textSize(20);
            text(hit[i][j] ? "H" : "X", width - 170 + i * 45, 30 + j * 25);
            popStyle();
        }
    }
    // draw logo
    if (logo != null) {
        image(logo, width - 180, height - 330, 160, 320);
    }
}

boolean isLastSpin() {
    for (int i = 0; i < 4; i++) {
        if (isSpinning[i]) {
            return false;
        }
    }
    return true;
}

void playWinLoseAudio() {
    int[][] currentVisibleIndices = getCurrentMatrixIndex();
    int[][] imageIdMatrix = indexToImageIndex(currentVisibleIndices);
    boolean[][] hit = getHittedMatrix(imageIdMatrix);
    boolean isHit = false;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 5; j++) {
            if (hit[i][j]) {
                isHit = true;
                break;
            }
        }
        if(isHit) break;
    }
    if (isHit) {
        if (winSound != null) {
            if (winSound.isRunning()) {
                winSound.stop();
            }
            winSound.setFramePosition(0);
            winSound.start();
        } else {
            println("Debug: Win condition met, but winSound is null or not loaded.");
        }
    } else {
        if (loseSound != null) {
            if (loseSound.isRunning()) {
                loseSound.stop();
            }
            loseSound.setFramePosition(0);
            loseSound.start();
        } else {
            println("Debug: Lose condition met, but loseSound is null or not loaded.");
        }
    }
}

void pressSpin(int reelIndex) {
    isSpinning[reelIndex] = false;
    fixPosition(reelIndex);

    if (isLastSpin()) {
        playWinLoseAudio();
    }
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

int[][] getCurrentMatrixIndex() {
    int[][] matrixIndices = new int[4][5];
    int reelStripLength = visibleImages * 2;

    for (int i = 0; i < 4; i++) {
        int normalizedCenterIndex = getNormalizedIndexOfImageOnHitline(i);
        for (int j_slot = 0; j_slot < 5; j_slot++) {
            int rawIndexInReel = normalizedCenterIndex + j_slot - 2;
            matrixIndices[i][j_slot] = (rawIndexInReel % reelStripLength + reelStripLength) % reelStripLength;
        }
    }
    return matrixIndices;
}

int[][] indexToImageIndex(int[][] matrixIndices) {
    int[][] imageIdMatrix = new int[4][5];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 5; j++) {
            if (reelImagesIndex != null && reelImagesIndex[i] != null && 
                matrixIndices[i][j] >= 0 && matrixIndices[i][j] < reelImagesIndex[i].length &&
                !slotImages.isEmpty()) {
                imageIdMatrix[i][j] = reelImagesIndex[i][matrixIndices[i][j]];
            } else {
                imageIdMatrix[i][j] = -1;
            }
        }
    }
    return imageIdMatrix;
}

boolean[][] getHittedMatrix(int[][] imageMatrix) {
    boolean[][] hit = new boolean[4][5];
    for (int y = 0; y < 5; y++) {
        for (int x = 0; x <= 4 - 3; x++) {
            if (imageMatrix[x][y] == imageMatrix[x+1][y] && imageMatrix[x][y] == imageMatrix[x+2][y]) {
                hit[x][y] = true;
                hit[x+1][y] = true;
                hit[x+2][y] = true;
            }
        }
    }
    for (int x = 0; x < 4; x++) {
        for (int y = 0; y <= 5 - 3; y++) {
            if (imageMatrix[x][y] == imageMatrix[x][y+1] && imageMatrix[x][y] == imageMatrix[x][y+2]) {
                hit[x][y] = true;
                hit[x][y+1] = true;
                hit[x][y+2] = true;
            }
        }
    }
    for (int x = 0; x <= 4 - 3; x++) {
        for (int y = 0; y <= 5 - 3; y++) {
            if (imageMatrix[x][y] == imageMatrix[x+1][y+1] && imageMatrix[x][y] == imageMatrix[x+2][y+2]) {
                hit[x][y] = true;
                hit[x+1][y+1] = true;
                hit[x+2][y+2] = true;
            }
        }
    }
    for (int x = 0; x <= 4 - 3; x++) {
        for (int y = 2; y < 5; y++) {
            if (imageMatrix[x][y] == imageMatrix[x+1][y-1] && imageMatrix[x][y] == imageMatrix[x+2][y-2]) {
                hit[x][y] = true;
                hit[x+1][y-1] = true;
                hit[x+2][y-2] = true;
            }
        }
    }
    return hit;
}

float getRawIndexOfImageOnHitline(int reelIdx) {
    return (positions[reelIdx] / imageHeight) - 0.5f + (float)visibleImages / 2.0f;
}

int getNormalizedIndexOfImageOnHitline(int reelIndex) {
    float rawIndex = getRawIndexOfImageOnHitline(reelIndex);
    int roundedRawIndex = round(rawIndex);
    int reelStripLength = visibleImages * 2;
    return (roundedRawIndex % reelStripLength + reelStripLength) % reelStripLength;
}

void fixPosition(int reelIndex) {
    float rawIndexOnHitline = getRawIndexOfImageOnHitline(reelIndex);
    int targetImageRawIndex = round(rawIndexOnHitline);

    positions[reelIndex] = imageHeight * (targetImageRawIndex + 0.5f - (float)visibleImages / 2.0f);

    float singleCycleHeight = (float)visibleImages * imageHeight;
    positions[reelIndex] = (positions[reelIndex] % singleCycleHeight + singleCycleHeight) % singleCycleHeight;
}

public void dispose() {
    if (winSound != null) {
        winSound.close();
    }
    if (loseSound != null) {
        loseSound.close();
    }
}


