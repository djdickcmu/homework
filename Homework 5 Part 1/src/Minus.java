/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: Minus.java
 * Description: This class represents a plus node in the arithmetic tree.
 * Its eval method returns the result of the right node's eval method subtracted from the left's eval method.
 * ToString will return the To string method of the children surrounded in parenthesis
 * with a minus between their results. 
 */
public class Minus extends Binop {
	public Minus(Node l, Node r) {
		super(l, r);
	}

	public double eval(double[] variableValues) {
		return lChild.eval(variableValues) - rChild.eval(variableValues);
	}

	public String toString() {
		return "(" + lChild.toString() + " - " + rChild.toString() + ")";
	}
}
