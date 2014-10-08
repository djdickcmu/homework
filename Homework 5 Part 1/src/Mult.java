/*Author: Dorsey Dick
 * Assignment: Homework 4 Part 1
 * File: Plus.java
 * Description: This class represents a plus node in the arithmetic tree.
 * Its eval method returns the result of the left and right node's eval method multiplied together.
 * ToString will return the To string method of the children surrounded in parenthesis
 * with a star between their results. 
 */
public class Mult extends Binop {
	public Mult(Node l, Node r) {
		super(l, r);
	}

	public double eval(double[] variableValues) {
		return lChild.eval(variableValues) * rChild.eval(variableValues);
	}

	public String toString() {
		return "(" + lChild.toString() + " * " + rChild.toString() + ")";
	}
}
