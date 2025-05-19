import java.util.ArrayList;
import java.io.File;
import processing.sound.*;

final int IMAGE_WIDTH = 100;
final int IMAGE_HEIGHT = 100;
final int VISIBLE_IMAGES = 8;
final int REEL_COUNT = 4;
final int PAYLINE_SIZE = 5;

ArrayList<PImage> slotImages;
float[] positions = new float[REEL_COUNT];
boolean[] isSpinning = new boolean[REEL_COUNT];
int[][] reelImagesIndex;
PImage logo;
SoundFile winSound;
SoundFile loseSound;

boolean needsFullRedraw = true;
int lastFrameCount = 0;
boolean[][] lastHitMatrix = null;
int frameUpdateInterval = 1;

void loadSlotImages() {
    slotImages = new ArrayList<PImage>();
    File[] files = listFiles(sketchPath("images"));
    if (files != null) {
        for (File file : files) {
            String path = file.getPath();
            if (path.toLowerCase().endsWith(".png") || path.toLowerCase().endsWith(".jpg")) {
                PImage img = loadImage(path);
                if (img != null) {
                    img.resize(IMAGE_WIDTH, IMAGE_HEIGHT);
                    slotImages.add(img);
                } else {
                    println("Error loading image: " + path);
                }
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
        winSound = new SoundFile(this, "audio/hit.wav");
    } catch (Exception e) {
        println("Error: Could not load audio/hit.wav. Audio playback for wins will be disabled.");
        winSound = null;
    }
    try {
        loseSound = new SoundFile(this, "audio/lost.wav");
    } catch (Exception e) {
        println("Error: Could not load audio/lost.wav. Audio playback for losses will be disabled.");
        loseSound = null;
    }
}

void randomizeReelImagesIndex() {
    if (slotImages == null || slotImages.isEmpty()) {
        println("Cannot randomize reel images: slotImages is null or empty. Call loadSlotImages() first.");
        return;
    }
    
    int reelStripLength = VISIBLE_IMAGES * 2;
    if (reelImagesIndex == null) {
        reelImagesIndex = new int[REEL_COUNT][reelStripLength];
    }
    
    for (int i = 0; i < REEL_COUNT; i++) {
        for (int j = 0; j < VISIBLE_IMAGES; j++) {
            reelImagesIndex[i][j] = (int) random(slotImages.size());
        }
        System.arraycopy(reelImagesIndex[i], 0, reelImagesIndex[i], VISIBLE_IMAGES, VISIBLE_IMAGES);
    }
    needsFullRedraw = true;
}

boolean isSpinningFinished() {
    for (int i = 0; i < REEL_COUNT; i++) {
        if (isSpinning[i]) {
            return false;
        }
    }
    return true;
}

void setup() {
    size(800, 600, P2D);
    frameRate(30);
    noSmooth();
    hint(DISABLE_TEXTURE_MIPMAPS);
    ((PGraphicsOpenGL)g).textureSampling(2);
    
    loadSlotImages();
    randomizeReelImagesIndex();
    loadAudio();
    
    logo = loadImage("logo.png");
    if (logo == null) {
        println("Error: Could not load logo.png. Logo will not be displayed.");
    } else {
        logo.resize(160, 320);
    }
    
    for (int i = 0; i < REEL_COUNT; i++) {
        isSpinning[i] = true;
    }
}

void drawHitBar() {
    colorMode(HSB, 360, 100, 100);
    float hue = (frameCount * 5) % 360;
    fill(hue, 60, 95, 220);
    stroke((hue + 180) % 360, 60, 100, 220);
    strokeWeight(3);
    int margin = 80;
    rect(margin, height / 2 - IMAGE_HEIGHT / 2, width - margin * 2, IMAGE_HEIGHT, 30);
    colorMode(RGB, 255, 255, 255);
}

int calcSpinSpeed() {
    int count = 0;
    for (int i = 0; i < REEL_COUNT; i++) {
        if (!isSpinning[i]) {
            count++;
        }
    }
    return 8 + count * 8;
}

void draw() {
    if (frameCount % frameUpdateInterval != 0 && !needsFullRedraw) {
        return;
    }
    
    background(255);
    
    int spinSpeed = calcSpinSpeed();
    boolean needsUpdate = false;
    
    for (int i = 0; i < REEL_COUNT; i++) {
        if (isSpinning[i]) {
            positions[i] += spinSpeed;
            float singleCycleHeight = VISIBLE_IMAGES * IMAGE_HEIGHT;
            if (positions[i] >= singleCycleHeight) {
                positions[i] -= singleCycleHeight;
            }
            needsUpdate = true;
        }
    }
    
    if (needsUpdate || needsFullRedraw || frameCount - lastFrameCount > 10) {
        int[][] currentVisibleIndices = getCurrentMatrixIndex();
        int[][] imageIdMatrix = indexToImageIndex(currentVisibleIndices);
        boolean[][] hit = getHittedMatrix(imageIdMatrix);
        lastHitMatrix = hit;
        drawReels(hit);
        drawHitMatrix(hit);
        lastFrameCount = frameCount;
    } else if (lastHitMatrix != null) {
        drawReels(lastHitMatrix);
        drawHitMatrix(lastHitMatrix);
    }
    
    drawButton();
    needsFullRedraw = false;
}

void drawReels(boolean[][] hit) {
    int reelDisplayStripLength = VISIBLE_IMAGES * 2;
    
    for (int i = 0; i < REEL_COUNT; i++) {
        int x = 40 + i * (IMAGE_WIDTH + 50);
        int y_reelVisibleTop = height/2 - (IMAGE_HEIGHT * VISIBLE_IMAGES)/2;
        
        pushStyle();
        colorMode(HSB, 360, 100, 100);
        float hue = (frameCount % 360);
        fill(hue, 60, 95, 180);
        stroke((hue + 180) % 360, 60, 100, 220);
        strokeWeight(3);
        rect(x - 5, y_reelVisibleTop - 5, IMAGE_WIDTH + 10, IMAGE_HEIGHT * VISIBLE_IMAGES + 10, 10);
        popStyle();
        
        int normalizedHitLineImageIndex = getNormalizedIndexOfImageOnHitline(i);
        
        int[] paylineWindowIndices = new int[PAYLINE_SIZE];
        for(int k = 0; k < PAYLINE_SIZE; k++) {
            paylineWindowIndices[k] = (normalizedHitLineImageIndex + k - 2 + reelDisplayStripLength) % reelDisplayStripLength;
        }

        for (int j = 0; j < reelDisplayStripLength; j++) {
            float imgY = y_reelVisibleTop + j * IMAGE_HEIGHT - positions[i];
            
            if (imgY + IMAGE_HEIGHT > y_reelVisibleTop && imgY < y_reelVisibleTop + VISIBLE_IMAGES * IMAGE_HEIGHT) {
                boolean isInPaylineWindow = false;
                int paylineSlot = -1;
                for(int k = 0; k < PAYLINE_SIZE; k++) {
                    if (j == paylineWindowIndices[k]) {
                        isInPaylineWindow = true;
                        paylineSlot = k;
                        break;
                    }
                }

                boolean isActuallyHitImage = isSpinningFinished() && isInPaylineWindow && hit[i][paylineSlot];
                
                if (slotImages.size() > reelImagesIndex[i][j]) {
                    pushStyle();
                    
                    if (isActuallyHitImage) {
                        colorMode(HSB, 360, 100, 100, 255);
                        float rainbowHue = (frameCount * 7 + i * 40 + j * 15) % 360;
                        tint(rainbowHue, 95, 100, 255);
                        
                        pushStyle();
                        colorMode(HSB, 360, 100, 100, 255);
                        stroke(rainbowHue, 95, 100, 255);
                        strokeWeight(6);
                        noFill();
                        rect(x - 4, imgY - 4, IMAGE_WIDTH + 8, IMAGE_HEIGHT + 8, 24);
                        popStyle();
                    } else if (isSpinningFinished()) {
                        if (isInPaylineWindow) {
                            tint(255, 80);
                            
                            pushStyle();
                            stroke(180, 100, 100, 80);
                            strokeWeight(2);
                            noFill();
                            rect(x, imgY, IMAGE_WIDTH, IMAGE_HEIGHT, 18);
                            popStyle();
                        } else {
                            tint(255, 40);
                        }
                    }
                    
                    int margin = 3;
                    image(slotImages.get(reelImagesIndex[i][j]), x + margin, imgY + margin, IMAGE_WIDTH - margin * 2, IMAGE_HEIGHT - margin * 2);
                    
                    popStyle();
                }
            }
        }
    }
}

void drawButton() {
    drawSingleButton(0, false, 255, 0, 0, "O");      // Red O
    drawSingleButton(1, false, 0, 0, 255, "X");      // Blue X
    drawSingleButton(2, false, 255, 105, 180, "[ ]"); // Pink Square
    drawSingleButton(3, false, 0, 255, 0, "△");      // Green Triangle
    
    drawSingleButton(0, true, 255, 0, 0, "O");      // Red O
    drawSingleButton(1, true, 0, 0, 255, "X");      // Blue X
    drawSingleButton(2, true, 255, 105, 180, "[ ]"); // Pink Square
    drawSingleButton(3, true, 0, 255, 0, "△");      // Green Triangle
}

void drawSingleButton(int index, boolean isBottom, int r, int g, int b, String symbol) {
    int y = isBottom ? height - 30 : -10;
    int textY = isBottom ? height - 10 : 20;
    int x = 30 + index * (IMAGE_WIDTH + 50);
    int buttonWidth = IMAGE_WIDTH + 20;
    
    noStroke();
    fill(r, g, b);
    rect(x, y, buttonWidth, 40, 30);
    
    fill(255, 255, 255);
    textSize(symbol.equals("[ ]") ? 22 : 20);
    
    float textOffsetX = symbol.equals("[ ]") ? -4 : -4;
    text(symbol, x + buttonWidth / 2 + textOffsetX, textY);
}

void drawHitMatrix(boolean[][] hit) {
    for (int i = 0; i < REEL_COUNT; i++) {
        for (int j = 0; j < PAYLINE_SIZE; j++) {
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
    
    if (logo != null) {
        image(logo, width - 180, height - 330, 160, 320);
    }
}

boolean isLastSpin() {
    for (int i = 0; i < REEL_COUNT; i++) {
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
    hitCheck: for (int i = 0; i < REEL_COUNT; i++) {
        for (int j = 0; j < PAYLINE_SIZE; j++) {
            if (hit[i][j]) {
                isHit = true;
                break hitCheck;
            }
        }
    }
    
    if (isHit) {
        if (winSound != null) {
            winSound.play();
        } else {
            println("Debug: Win condition met, but winSound is null.");
        }
    } else {
        if (loseSound != null) {
            loseSound.play();
        } else {
            println("Debug: Lose condition met, but loseSound is null.");
        }
    }
}

void pressSpin(int reelIndex) {
    if (reelIndex >= 0 && reelIndex < REEL_COUNT && isSpinning[reelIndex]) {
        isSpinning[reelIndex] = false;
        fixPosition(reelIndex);
        needsFullRedraw = true;

        if (isLastSpin()) {
            playWinLoseAudio();
        }
    }
}

void resetSpinning() {
    randomizeReelImagesIndex();
    isSpinning = new boolean[REEL_COUNT];
    positions = new float[REEL_COUNT];
    
    for (int i = 0; i < REEL_COUNT; i++) {
        isSpinning[i] = true;
        positions[i] = 0;
    }
    
    needsFullRedraw = true;
}

void keyPressed() {
    if (key == ' ') {
        resetSpinning();
    } else if (key >= '1' && key <= '4') {
        int reelIndex = key - '1';
        pressSpin(reelIndex);
    }
}

int[][] getCurrentMatrixIndex() {
    int[][] matrixIndices = new int[REEL_COUNT][PAYLINE_SIZE];
    int reelStripLength = VISIBLE_IMAGES * 2;

    for (int i = 0; i < REEL_COUNT; i++) {
        int normalizedCenterIndex = getNormalizedIndexOfImageOnHitline(i);
        for (int j_slot = 0; j_slot < PAYLINE_SIZE; j_slot++) {
            int rawIndexInReel = normalizedCenterIndex + j_slot - 2;
            matrixIndices[i][j_slot] = (rawIndexInReel % reelStripLength + reelStripLength) % reelStripLength;
        }
    }
    return matrixIndices;
}

int[][] indexToImageIndex(int[][] matrixIndices) {
    int[][] imageIdMatrix = new int[REEL_COUNT][PAYLINE_SIZE];
    for (int i = 0; i < REEL_COUNT; i++) {
        for (int j = 0; j < PAYLINE_SIZE; j++) {
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
    boolean[][] hit = new boolean[REEL_COUNT][PAYLINE_SIZE];
    
    for (int y = 0; y < PAYLINE_SIZE; y++) {
        for (int x = 0; x <= REEL_COUNT - 3; x++) {
            if (imageMatrix[x][y] != -1 && 
                imageMatrix[x][y] == imageMatrix[x+1][y] && 
                imageMatrix[x][y] == imageMatrix[x+2][y]) {
                hit[x][y] = hit[x+1][y] = hit[x+2][y] = true;
            }
        }
    }
    
    for (int x = 0; x < REEL_COUNT; x++) {
        for (int y = 0; y <= PAYLINE_SIZE - 3; y++) {
            if (imageMatrix[x][y] != -1 && 
                imageMatrix[x][y] == imageMatrix[x][y+1] && 
                imageMatrix[x][y] == imageMatrix[x][y+2]) {
                hit[x][y] = hit[x][y+1] = hit[x][y+2] = true;
            }
        }
    }
    
    for (int x = 0; x <= REEL_COUNT - 3; x++) {
        for (int y = 0; y <= PAYLINE_SIZE - 3; y++) {
            if (imageMatrix[x][y] != -1 && 
                imageMatrix[x][y] == imageMatrix[x+1][y+1] && 
                imageMatrix[x][y] == imageMatrix[x+2][y+2]) {
                hit[x][y] = hit[x+1][y+1] = hit[x+2][y+2] = true;
            }
        }
    }
    
    for (int x = 0; x <= REEL_COUNT - 3; x++) {
        for (int y = 2; y < PAYLINE_SIZE; y++) {
            if (imageMatrix[x][y] != -1 && 
                imageMatrix[x][y] == imageMatrix[x+1][y-1] && 
                imageMatrix[x][y] == imageMatrix[x+2][y-2]) {
                hit[x][y] = hit[x+1][y-1] = hit[x+2][y-2] = true;
            }
        }
    }
    
    return hit;
}

float getRawIndexOfImageOnHitline(int reelIdx) {
    return (positions[reelIdx] / IMAGE_HEIGHT) - 0.5f + (float)VISIBLE_IMAGES / 2.0f;
}

int getNormalizedIndexOfImageOnHitline(int reelIndex) {
    float rawIndex = getRawIndexOfImageOnHitline(reelIndex);
    int roundedRawIndex = round(rawIndex);
    int reelStripLength = VISIBLE_IMAGES * 2;
    return (roundedRawIndex % reelStripLength + reelStripLength) % reelStripLength;
}

void fixPosition(int reelIndex) {
    float rawIndexOnHitline = getRawIndexOfImageOnHitline(reelIndex);
    int targetImageRawIndex = round(rawIndexOnHitline);

    positions[reelIndex] = IMAGE_HEIGHT * (targetImageRawIndex + 0.5f - (float)VISIBLE_IMAGES / 2.0f);

    float singleCycleHeight = (float)VISIBLE_IMAGES * IMAGE_HEIGHT;
    positions[reelIndex] = (positions[reelIndex] % singleCycleHeight + singleCycleHeight) % singleCycleHeight;
}




