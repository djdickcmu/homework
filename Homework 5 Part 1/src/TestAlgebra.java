/*Author: Dorsey Dick
 * Assignment: Homework 5 Part 1
 * File: TestArithmetic.java
 * Description: This class is used to show the capabilities of the arithmetic 
 * classes. It builds a binary tree with 4 leaves that are constant values. The parents
 * are binary operations and the root node is a binary operation.
 * Once the tree is built it calls the ToString methods to display the 
 * arithmetic problem, and eval to display the result.
 */

import java.util.Random;

public class TestAlgebra {

	static Random randomGenerator = new Random();

	public static void main(String[] args) {
		double[] doubleArray1 = { 1.0, 2.0, 3.0 };
		double[] doubleArray2 = { 4.0, 5.0, 6.0 };
		Node n;
		for (int i = 0; i < 5; i++) {
			n = randOperator(
					randOperator(randConstOrVariable(), randConstOrVariable()),
					randOperator(randConstOrVariable(), randConstOrVariable()));
			System.out.format("{X0, X1, X2} = {1, 2, 3} " + n.toString()
					+ " = %.2f%n", n.eval(doubleArray1));
			System.out.format("{X0, X1, X2} = {4, 5, 6} " + n.toString()
					+ " = %.2f%n", n.eval(doubleArray2));
			System.out.println();
		}

	}

	// returns a constant node with an integer value between 1 and 20,
	// inclusive. The value is represented as a double
	public static Node randConstOrVariable() {
		if (randomGenerator.nextBoolean()) {

			int i = randomGenerator.nextInt(20) + 1;
			return new Const(i * 1.0);
		} else {
			return new Variable(randomGenerator.nextInt(3));
		}
	}

	// Takes 2 node arguments and uses them as the children for a binary
	// operator node. The binary operation is picked randomly.
	public static Node randOperator(Node l, Node r) {
		switch (randomGenerator.nextInt(4)) {
		case 0:
			return new Plus(l, r);
		case 1:
			return new Minus(l, r);
		case 2:
			return new Divide(l, r);
		default:
			return new Mult(l, r);
		}
	}
}
