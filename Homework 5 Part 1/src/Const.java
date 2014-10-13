/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: Const.java
 * Description: This class represents a plus node in the arithmetic tree.
 * Its eval method returns its value.
 * ToString returns the string representation of the double value. 
 */
public class Const extends Node {
	private double value;

	public Const(double d) {
		value = d;
	}

	public double eval(double[] variableValues) {
		return value;
	}

	public String toString() {
		return Double.toString(value);
	}
}
