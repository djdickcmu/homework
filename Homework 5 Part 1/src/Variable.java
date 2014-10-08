/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: Const.java
 * Description: This class represents a plus node in the arithmetic tree.
 * Its eval method returns its value.
 * ToString returns the string representation of the double value. 
 */
public class Variable extends Node {
	//private double value;
	int index;

	public Variable(int i) {
		index = i;
	}

	public double eval(double[] variableValues) {
		return variableValues[index];
	}
	public String toString(){
		return "X" + index;
	}
}
