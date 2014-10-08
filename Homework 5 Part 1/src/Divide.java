/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: Divide.java
 * Description: This class represents a plus node in the arithmetic tree.
 * Its eval method returns the result of the left node's eval method divided by the right node's eval method.
 * ToString will return the To string method of the children surrounded in parenthesis
 * with a slash between their results. 
 */
public class Divide extends Binop {
	public Divide(Node l, Node r) {
		super(l, r);
	}

	public double eval(double[] variableValues) {
		return lChild.eval(variableValues) / rChild.eval(variableValues);
	}
	public String toString(){
		return "(" + lChild.toString() + " / " + rChild.toString() + ")";
	}
}
