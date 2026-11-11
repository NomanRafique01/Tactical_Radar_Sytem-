
import processing.serial.*;

// =====================================================
// ZYRON RADAR - ADVANCED TACTICAL RADAR INTERFACE
// Smooth Sweep | Phosphor Trail | Target Lock | HUD
// =====================================================

Serial myPort;

// ---------------- RADAR CONFIGURATION ----------------

int maxDistance = 40;

float centerX;
float centerY;
float radarRadius;

int radarAngle = 0;
int objectDistance = -1;

float displayAngle = 0;
float previousDisplayAngle = 0;

int sweepDirection = 1;

final int ALERT_CM = 30;
final int RELEASE_CM = 35;

final int DETECT_LIMIT = 3;
final int CLEAR_LIMIT = 3;

int detectCount = 0;
int clearCount = 0;

boolean objectDetected = false;

// ---------------- TARGET DATA ----------------

float detectedAngle = 0;
float detectedDistance = 0;

float targetPulse = 0;
float lockAnimation = 0;

// ---------------- ANIMATION ----------------

float animationTime = 0;

float sweepSpeed = 0.24;

int trailSteps = 55;

float[] trailAlpha = new float[trailSteps];

// ---------------- COLORS ----------------

color GREEN = color(0, 255, 75);
color BRIGHT_GREEN = color(100, 255, 130);
color DARK_GREEN = color(0, 75, 30);

color RED = color(255, 35, 35);
color BRIGHT_RED = color(255, 100, 100);

color WHITE = color(220, 240, 220);

color BACKGROUND = color(1, 7, 5);

// ---------------- SETUP ----------------

void setup() {

  size(1200, 750);

  smooth(8);

  frameRate(60);

  surface.setTitle("TACTICAL RADAR SYSTEM");

  centerX = width / 2.0;

  centerY = height - 145;

  radarRadius = min(
    width * 0.43,
    height - 260
  );

  for (int i = 0; i < trailSteps; i++) {
    trailAlpha[i] = 0;
  }

  println("AVAILABLE SERIAL PORTS:");

  printArray(Serial.list());

  try {

    if (Serial.list().length > 0) {

      // Change index if your Arduino uses another port.

      myPort = new Serial(
        this,
        Serial.list()[0],
        9600
      );

      myPort.clear();

      myPort.bufferUntil('\n');

      println("ARDUINO CONNECTED");

    }

  }
  catch(Exception e) {

    println("ARDUINO CONNECTION FAILED");

  }
}

// =====================================================
// SERIAL COMMUNICATION
// =====================================================

void serialEvent(Serial p) {

  String data = p.readStringUntil('\n');

  if (data == null) return;

  data = trim(data);

  String[] values = split(data, ',');

  if (values.length != 2) return;

  try {

    int angle = int(values[0]);

    int distance = int(values[1]);

    if (angle < 0 || angle > 180) return;

    if (angle > radarAngle) {
      sweepDirection = 1;
    }

    else if (angle < radarAngle) {
      sweepDirection = -1;
    }

    radarAngle = angle;

    objectDistance = distance;

    // ---------------- DETECTION FILTER ----------------

    if (!objectDetected) {

      if (distance > 0 && distance <= ALERT_CM) {

        detectCount++;

      }

      else {

        detectCount = 0;

      }

      if (detectCount >= DETECT_LIMIT) {

        objectDetected = true;

        detectedAngle = radarAngle;

        detectedDistance = distance;

        detectCount = 0;

        clearCount = 0;

      }

    }

    // ---------------- TARGET TRACKING ----------------

    else {

      if (distance < 0 || distance > RELEASE_CM) {

        clearCount++;

      }

      else {

        clearCount = 0;

        // Update target position when another valid
        // detection occurs near the locked target.

        if (distance > 0) {

          detectedAngle = radarAngle;

          detectedDistance = distance;

        }

      }

      if (clearCount >= CLEAR_LIMIT) {

        objectDetected = false;

        clearCount = 0;

        detectCount = 0;

      }

    }

  }

  catch(Exception e) {

    println("INVALID SERIAL DATA");

  }
}

// =====================================================
// MAIN DRAW
// =====================================================

void draw() {

  background(BACKGROUND);

  animationTime += 0.016;

  // Smooth interpolation of Arduino servo angle.

  previousDisplayAngle = displayAngle;

  displayAngle = lerp(
    displayAngle,
    radarAngle,
    sweepSpeed
  );

  // Small animation updates.

  targetPulse += 0.018;

  if (targetPulse > 1) {
    targetPulse = 0;
  }

  lockAnimation = lerp(
    lockAnimation,
    objectDetected ? 1 : 0,
    0.08
  );

  drawBackground();

  drawHeader();

  drawRadarGrid();

  drawRadarSweep();

  if (objectDetected) {

    drawTargetZone();

    drawDetectedTarget();

  }

  drawInformationPanel();

  drawFooter();

}

// =====================================================
// BACKGROUND
// =====================================================

void drawBackground() {

  // Subtle horizontal scan lines.

  stroke(0, 35, 15, 35);

  strokeWeight(1);

  for (int y = 0; y < height; y += 5) {

    line(0, y, width, y);

  }

  // Soft green center glow.

  noStroke();

  for (int i = 10; i >= 1; i--) {

    fill(0, 80, 25, 2);

    ellipse(
      centerX,
      centerY,
      radarRadius * 2.5 * i / 10.0,
      radarRadius * 2.5 * i / 10.0
    );

  }

}

// =====================================================
// HEADER
// =====================================================

void drawHeader() {

  textAlign(CENTER);

  fill(GREEN);

  textSize(26);

  text(
    "TACTICAL RADAR SYSTEM",
    width / 2,
    35
  );

  stroke(DARK_GREEN);

  strokeWeight(1);

  line(30, 52, width-30, 52);

  textSize(12);

  fill(120, 190, 130);

  text(
    "180 DEGREE SURVEILLANCE | LIVE SCANNING",
    width / 2,
    72
  );

  // Connection indicator.

  noStroke();

  fill(myPort != null ? GREEN : RED);

  ellipse(width-45, 32, 9, 9);

  textAlign(RIGHT);

  fill(WHITE);

  textSize(10);

  text(
    myPort != null ? "SYSTEM ONLINE" : "OFFLINE",
    width-58,
    36
  );

}

// =====================================================
// RADAR GRID
// =====================================================

void drawRadarGrid() {

  pushStyle();

  // Distance rings.

  for (int d = 10; d <= maxDistance; d += 10) {

    float r = radarRadius * d / maxDistance;

    noFill();

    stroke(0, 135, 55, 100);

    strokeWeight(1);

    arc(
      centerX,
      centerY,
      r*2,
      r*2,
      PI,
      TWO_PI
    );

    // Ring labels.

    fill(70, 220, 100);

    noStroke();

    textAlign(LEFT);

    textSize(11);

    text(
      d + " CM",
      centerX + 8,
      centerY-r-5
    );

  }

  // Angular divisions.

  for (int a = 0; a <= 180; a += 15) {

    float rad = radians(a);

    float x = centerX + radarRadius*cos(rad);

    float y = centerY - radarRadius*sin(rad);

    stroke(
      a % 30 == 0 ? color(0, 115, 45, 100)
                  : color(0, 70, 30, 55)
    );

    strokeWeight(a % 30 == 0 ? 1 : 0.6);

    line(
      centerX,
      centerY,
      x,
      y
    );

    if (a % 30 == 0) {

      float labelR = radarRadius + 27;

      float lx = centerX + labelR*cos(rad);

      float ly = centerY - labelR*sin(rad);

      fill(GREEN);

      noStroke();

      textAlign(CENTER, CENTER);

      textSize(12);

      text(a + "°", lx, ly);

    }

  }

  // Baseline.

  stroke(GREEN);

  strokeWeight(2);

  line(
    centerX-radarRadius,
    centerY,
    centerX+radarRadius,
    centerY
  );

  // Center transmitter.

  noStroke();

  fill(GREEN);

  ellipse(centerX, centerY, 9, 9);

  fill(0, 255, 70, 45);

  ellipse(centerX, centerY, 25, 25);

  popStyle();

}

// =====================================================
// RADAR SWEEP
// =====================================================

void drawRadarSweep() {

  float currentAngle = displayAngle;

  float currentRad = radians(currentAngle);

  // ----------------------------------
  // PHOSPHOR TRAIL
  // ----------------------------------

  for (int i = trailSteps-1; i >= 1; i--) {

    float previousAngle =
      currentAngle - sweepDirection * i * 0.48;

    float nextAngle =
      currentAngle - sweepDirection * (i-1) * 0.48;

    previousAngle = constrain(previousAngle, 0, 180);

    nextAngle = constrain(nextAngle, 0, 180);

    float a1 = radians(previousAngle);

    float a2 = radians(nextAngle);

    float alpha = map(
      i,
      trailSteps,
      1,
      2,
      45
    );

    noStroke();

    fill(0, 255, 75, alpha);

    beginShape();

    vertex(centerX, centerY);

    vertex(
      centerX + radarRadius*cos(a1),
      centerY - radarRadius*sin(a1)
    );

    vertex(
      centerX + radarRadius*cos(a2),
      centerY - radarRadius*sin(a2)
    );

    endShape(CLOSE);

  }

  // ----------------------------------
  // MAIN BEAM POSITION
  // ----------------------------------

  float x = centerX + radarRadius*cos(currentRad);

  float y = centerY - radarRadius*sin(currentRad);

  // Outer glow.

  stroke(0, 255, 75, 12);

  strokeWeight(18);

  line(centerX, centerY, x, y);

  // Middle glow.

  stroke(0, 255, 75, 35);

  strokeWeight(9);

  line(centerX, centerY, x, y);

  // Inner beam.

  stroke(0, 255, 100, 100);

  strokeWeight(4);

  line(centerX, centerY, x, y);

  // Bright beam.

  stroke(BRIGHT_GREEN);

  strokeWeight(1.5);

  line(centerX, centerY, x, y);

  // Beam tip.

  noStroke();

  fill(0, 255, 75, 25);

  ellipse(x, y, 32, 32);

  fill(0, 255, 75, 65);

  ellipse(x, y, 17, 17);

  fill(WHITE);

  ellipse(x, y, 4, 4);

  // Transmitter glow.

  fill(0, 255, 75, 35);

  ellipse(centerX, centerY, 28, 28);

  fill(GREEN);

  ellipse(centerX, centerY, 8, 8);

}

// =====================================================
// TARGET DETECTION ZONE
// =====================================================

void drawTargetZone() {

  float targetRad = radians(detectedAngle);

  float targetR =
    radarRadius * detectedDistance / maxDistance;

  // Red sector around detected bearing.

  float sectorWidth = 3.5;

  noStroke();

  fill(255, 0, 0, 13);

  beginShape();

  vertex(centerX, centerY);

  for (
    float a = detectedAngle-sectorWidth;
    a <= detectedAngle+sectorWidth;
    a += 0.5
  ) {

    float rad = radians(a);

    vertex(
      centerX + targetR*cos(rad),
      centerY - targetR*sin(rad)
    );

  }

  endShape(CLOSE);

  // Red illuminated target region.

  float x = centerX + targetR*cos(targetRad);

  float y = centerY - targetR*sin(targetRad);

  noStroke();

  fill(255, 0, 0, 16);

  ellipse(x, y, 75, 75);

  fill(255, 0, 0, 12);

  ellipse(x, y, 105, 105);

}

// =====================================================
// DETECTED TARGET
// =====================================================

void drawDetectedTarget() {

  float rad = radians(detectedAngle);

  float r =
    radarRadius * detectedDistance / maxDistance;

  float x = centerX + r*cos(rad);

  float y = centerY - r*sin(rad);

  // ----------------------------------
  // EXPANDING PULSE RINGS
  // ----------------------------------

  for (int i = 0; i < 4; i++) {

    float phase =
      (targetPulse + i*0.25) % 1.0;

    float size = 12 + phase*55;

    float alpha = 190*(1-phase);

    noFill();

    stroke(255, 25, 25, alpha);

    strokeWeight(2);

    ellipse(x, y, size, size);

  }

  // ----------------------------------
  // OUTER RED GLOW
  // ----------------------------------

  noStroke();

  fill(255, 0, 0, 15);

  ellipse(x, y, 70, 70);

  fill(255, 0, 0, 30);

  ellipse(x, y, 42, 42);

  // ----------------------------------
  // TARGET CORE
  // ----------------------------------

  fill(255, 0, 0, 45);

  ellipse(x, y, 27, 27);

  fill(255, 30, 30, 110);

  ellipse(x, y, 17, 17);

  fill(RED);

  ellipse(x, y, 9, 9);

  fill(WHITE);

  ellipse(x, y, 3, 3);

  // ----------------------------------
  // TARGET CROSSHAIR
  // ----------------------------------

  stroke(RED);

  strokeWeight(1.3);

  noFill();

  ellipse(x, y, 35, 35);

  line(x-24, y, x-12, y);

  line(x+12, y, x+24, y);

  line(x, y-24, x, y-12);

  line(x, y+12, x, y+24);

  // ----------------------------------
  // TARGET INFORMATION POPUP
  // ----------------------------------

  drawTargetPopup(x, y);

}

// =====================================================
// TARGET POPUP
// =====================================================

void drawTargetPopup(float x, float y) {

  float boxW = 145;

  float boxH = 55;

  float bx = x + 35;

  float by = y - 55;

  // Keep popup inside screen.

  if (bx + boxW > width-15) {
    bx = x - boxW - 35;
  }

  if (by < 95) {
    by = y + 35;
  }

  // Connector.

  stroke(255, 40, 40, 180);

  strokeWeight(1);

  line(
    x,
    y,
    bx + (bx > x ? 0 : boxW),
    by + 28
  );

  // Popup background.

  noStroke();

  fill(12, 3, 3, 225);

  rect(bx, by, boxW, boxH);

  // Red border.

  noFill();

  stroke(RED);

  strokeWeight(1);

  rect(bx, by, boxW, boxH);

  // Information.

  fill(RED);

  textAlign(LEFT);

  textSize(11);

  text("TARGET DETECTED", bx+8, by+15);

  fill(WHITE);

  textSize(11);

  text(
    "RANGE: " + nf(detectedDistance, 0, 1) + " CM",
    bx+8,
    by+31
  );

  fill(BRIGHT_RED);

  text(
    "BEARING: " + int(detectedAngle) + " DEG",
    bx+8,
    by+45
  );

}

// =====================================================
// INFORMATION PANEL
// =====================================================

void drawInformationPanel() {

  // Bottom divider.

  stroke(DARK_GREEN);

  line(
    30,
    height-90,
    width-30,
    height-90
  );

  // Current angle.

  fill(GREEN);

  textAlign(LEFT);

  textSize(14);

  text(
    "BEARING: " + int(displayAngle) + "°",
    40,
    height-48
  );

  // Distance.

  textAlign(CENTER);

  fill(WHITE);

  String distanceText = "-- CM";

  if (objectDetected) {

    distanceText =
      nf(detectedDistance, 0, 1) + " CM";

  }

  text(
    "DISTANCE: " + distanceText,
    width/2,
    height-48
  );

  // Target status.

  textAlign(RIGHT);

  fill(objectDetected ? RED : GREEN);

  text(
    objectDetected ? "TARGET LOCKED" : "SCANNING",
    width-40,
    height-48
  );

  // Status indicator.

  noStroke();

  fill(objectDetected ? RED : GREEN);

  ellipse(
    width-160,
    height-53,
    7,
    7
  );

}

// =====================================================
// FOOTER
// =====================================================

void drawFooter() {

  fill(80, 160, 100);

  textAlign(CENTER);

  textSize(10);

  text(
    "TACTICAL SURVEILLANCE  |  180 DEGREE RADAR  |  LIVE TRACKING",
    width/2,
    height-12
  );

}
