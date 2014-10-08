/*Author: Dorsey Dick
 * Assignment: Homework 4 Part 2
 * File: Glyph.java (Taken from week 5 lecture)
 * Description: This file is used to demonstrate when the default is set for
 * member variables in the children classes. 
 * This will call the child's draw method at various points to show where the value of radius is set.
 */
public abstract class Glyph {
	void draw() {
		System.out.println("Glyph.draw()");
	}

	Glyph() {
		System.out.println("Glyph() before draw");
		draw();
		System.out.println("Glyph() after draw");
	}
}
