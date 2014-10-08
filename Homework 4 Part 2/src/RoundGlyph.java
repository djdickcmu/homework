/*Author: Dorsey Dick
 * Assignment: Homework 4 Part 2
 * File: GlyphTest.java (taken from week 5 lecture)
 * Description: This class extends Glyph. It is used to show how radius is set at various points.
 * Radius will be set when the member variable gets created when the implicit super() call is made.
 * Radius then gets set to the default of 1 after the implicit super() call.
 * The next line sets radius to the argument r in the constructor.
 */

class RoundGlyph extends Glyph {
	int radius = 1;

	RoundGlyph(int r) {
		//Radius get set to 1 right here, after implicit super() call. Gets overwritten by r on the next line.
		//Radius is set to 1 after super() but before radius = r;
		System.out.println("RoundGlphy() after implicit super(), before radius = r. radius = " + radius);
		radius = r;
		System.out.println("RoundGlyph(), radius=" + radius);
	}

	void draw() {
		System.out.println("RoundGlyph.draw(), radius=" + radius);
	}
}
