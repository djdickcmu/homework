/*Author: Dorsey Dick
 * Assignment: Homework 4 Part 1
 * File: Node.java
 * Description: This is an abstract class for a node in an arithmetic tree.
 * The node must be able to return an evaluation self as a double and must be able
 * to return a string representing itself.
 */

public abstract class Node {
	public Node() {
	}

	public abstract double eval(double[] variableValues);

	public abstract String toString();
}
