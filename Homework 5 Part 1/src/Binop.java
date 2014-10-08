/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: Binop.java
 * Description: Taken from the Week 5 lecture slides. This extends the
 * abstract node class. It allows for binary operations to be defined (+, -, *, /).
 * It holds 2 nodes and and expects the child classes to implement methods to
 * evaluate themselves and represent themselves as strings. 
 */

public abstract class Binop extends Node {
	protected Node lChild, rChild;

	public Binop(Node l, Node r) {
		lChild = l;
		rChild = r;
	}
}
