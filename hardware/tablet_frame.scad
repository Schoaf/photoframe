// Insert that holds a Samsung Galaxy Tab A 10.1 (SM-T585) in an IKEA
// RÖDALM 21x30 frame, with the lit display centred in the frame.
//
// Units mm. Seen from the front: x to the right, y up, z = 0 is the front
// (glass side), z = thickness is the back. The tablet lies landscape with
// USB on the left; power and volume are then on the top edge.
//
// The buttons are pressed from the back: a plunger pokes through the back
// panel, its 45° ramp pushes a slider against the button. The button's own
// spring pushes both back.
//
// Print the two halves front face down, black. Sliders and plungers lie
// flat as exported.

part = "assembly"; // [assembly, left, right, slider, plunger] - 3 sliders, 3 plungers

/* [Frame] */
frame_w = 300;          // inside of the frame
frame_h = 200;
frame_clearance = 0.5;  // total per axis

/* [Tablet, landscape, USB left] */
tablet_l = 254.2;
tablet_w = 155.3;
tablet_t = 8.2;
pocket_clearance = 0.3; // per side
// Tablet edge to lit display area (display 215 x 135).
bezel_left = 22.6;      // USB side
bezel_right = 16.6;     // home button side
bezel_top = 10.15;
bezel_bottom = 10.15;

/* [Buttons, top edge, measured from the tablet's left (USB) end] */
power = [30, 40];
volume = [51, 72];
button_protrusion = 1;
// One actuator each: power, volume up/down halves.
actuators = [35, 56, 67];

/* [Openings] */
usb_w = 18;             // pocket for an angled USB-C plug
speaker = [22, 41];     // right end, from each long edge
speaker_depth = 8;
front_skin = 1.2;       // closed front behind the pockets

/* [Actuators] */
act_clear = 0.25;
slider_w = 5;
slider_z0 = 1.8;
slider_back_len = 5;    // slider length at its back face
plunger_d = 6;          // body, larger than the hole in the back panel
plunger_min_z = 2.4;    // flat tip, leaves 1.5 mm stroke above the floor
plunger_floor = 0.8;
stem = 3.5;             // square stem through a 5.5 mm hole
stem_len = 9;           // back panel (~3) plus what you push

/* [Split] */
lap = 10;

$fn = 48;
T = tablet_t;
case_w = frame_w - frame_clearance;
case_h = frame_h - frame_clearance;
c = pocket_clearance;

display_w = tablet_l - bezel_left - bezel_right;
display_h = tablet_w - bezel_top - bezel_bottom;
// Tablet's lower left corner, so that the display centre is at 0,0.
x0 = -(bezel_left + display_w / 2);
y0 = -(bezel_bottom + display_h / 2);
y_top = y0 + tablet_w;

// Actuator geometry in the y-z plane: ramp plane y + z = ramp_c.
slider_z1 = T - 0.2;
tip_y = y_top + button_protrusion;
ramp_c = tip_y + slider_back_len + slider_z1;
py0 = ramp_c - slider_z1 + 1;
py1 = py0 + plunger_d;
stem_y = (py0 + py1) / 2;

module case_body() {
  difference() {
    translate([-case_w / 2, -case_h / 2, 0]) cube([case_w, case_h, T]);
    // Tablet
    translate([x0 - c, y0 - c, -1]) cube([tablet_l + 2 * c, tablet_w + 2 * c, T + 2]);
    // Room for the protruding buttons
    for (r = [power, volume])
      translate([x0 + r[0] - 1, y_top + c - 0.01, -1])
        cube([r[1] - r[0] + 2, button_protrusion + 0.4, T + 2]);
    // Actuator channels, open to the back
    for (a = actuators) {
      x = x0 + a;
      translate([x - slider_w / 2 - act_clear, y_top + c - 0.01, slider_z0 - 0.2])
        cube([slider_w + 2 * act_clear, ramp_c - slider_z0 - y_top - c + act_clear, T]);
      translate([x - plunger_d / 2 - act_clear, py0 - act_clear, plunger_floor])
        cube([plunger_d + 2 * act_clear, plunger_d + 2 * act_clear, T]);
    }
    // USB plug and cable, open to the back
    translate([-case_w / 2 + 2, -usb_w / 2, front_skin])
      cube([x0 - c + case_w / 2 - 2 + 0.01, usb_w, T]);
    // Speakers, open to the back
    for (s = [[y_top - speaker[1], y_top - speaker[0]], [y0 + speaker[0], y0 + speaker[1]]])
      translate([x0 + tablet_l + c - 0.01, s[0], front_skin])
        cube([speaker_depth, s[1] - s[0], T]);
  }
}

module left_mask() {
  translate([-500, -500, -50]) cube([500 - lap / 2, 1000, 100]);
  translate([-lap / 2, -500, -50]) cube([lap, 1000, 50 + T / 2]);
}

module left_half() { intersection() { case_body(); left_mask(); } }
module right_half() { difference() { case_body(); left_mask(); } }

// Profiles in the y-z plane, relative to the tip / plunger front.
module slider(w) {
  linear_extrude(w)
    polygon([
      [0, slider_z0],
      [ramp_c - slider_z0 - tip_y, slider_z0],
      [ramp_c - slider_z1 - tip_y, slider_z1],
      [0, slider_z1],
    ]);
}

module plunger() {
  y_flat = ramp_c - plunger_min_z;
  linear_extrude(plunger_d)
    polygon([
      [py0, ramp_c - py0],
      [y_flat, plunger_min_z],
      [py1, plunger_min_z],
      [py1, T],
      [py0, T],
    ]);
  // Stem, square and on the bed so it prints without support.
  translate([stem_y - stem / 2, T - 0.01, 0]) cube([stem, stem_len, stem]);
}

// Moves a flat-printed part to its place in the frame.
module placed(x, w) {
  translate([x - w / 2, 0, 0]) rotate([90, 0, 90]) children();
}

module assembly() {
  color("dimgray") left_half();
  color("gray") right_half();
  color("white", 0.3) translate([x0, y0, 0]) cube([tablet_l, tablet_w, T]);
  color("deepskyblue", 0.5)
    translate([-display_w / 2, -display_h / 2, -0.2]) cube([display_w, display_h, 0.2]);
  for (i = [0 : len(actuators) - 1]) {
    x = x0 + actuators[i];
    color("orange") placed(x, slider_w) translate([tip_y, 0, 0]) slider(slider_w);
    color("red") translate([x - plunger_d / 2, 0, 0]) rotate([90, 0, 90]) plunger();
  }
}

if (part == "assembly") assembly();
else if (part == "left") left_half();
// Back face down, so its half of the lap joint lies on the bed.
else if (part == "right") translate([0, 0, T]) rotate([0, 180, 0]) right_half();
else if (part == "slider") slider(slider_w);
else if (part == "plunger") translate([-py0, 0, 0]) plunger();

// Holes in the back panel, seen from the BACK: the USB side is then on the
// right, so distances are from the right inner edge of the frame.
for (i = [0 : len(actuators) - 1])
  echo(str("Plunger ", i + 1, ": ", frame_w / 2 + x0 + actuators[i] - plunger_d / 2 + stem / 2,
    " mm from the right inner edge, ", frame_h / 2 - stem_y, " mm from the top, drill 5.5 mm"));
echo(str("USB pocket: ", frame_w / 2 - case_w / 2 + 2, "-", frame_w / 2 + x0 - c,
  " mm from the right inner edge, ", frame_h / 2 - usb_w / 2, "-", frame_h / 2 + usb_w / 2, " mm from the top"));
