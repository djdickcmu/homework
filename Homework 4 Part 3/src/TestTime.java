/*Author: Dorsey Dick
 * Assignment: Homework 4 Part 3
 * File: TestTime.java
 * Description: This class is a test driver for the Time class.
 * It test the equals method and uses various comparisons to show
 * the equals method is reflexive, symmetric, and transitive. It also shows comparisons to null objects
 * and objects of a different class
 */

public class TestTime {
	public static void main(String[] args) {
		Time t1 = new Time();
		Time t2 = new Time(20, 3, 45);

		t1.setHour(7).setMinute(32).setSecond(23);
		System.out.println("t1 is " + t1);
		System.out.println("t2 is " + t2);
		System.out.println("t1 equal to t2? " + t1.equals(t2));
		
		t1 = new Time(20, 3, 45);
		System.out.println("\nt1 is " + t1);
		System.out.println("t2 is " + t2);
		System.out.println("Symmetric: t1 equal to t2? " + t1.equals(t2));
		System.out.println("t2 equal to t1? " + t2.equals(t1));
		
		System.out.println("\nt1 equal to a string? " + t1.equals("a string"));
		
		Time t3 = new Time (20, 3, 45);
		System.out.println("\nt3 is " + t3);
		System.out.println("Transitive: t1 equal to t2? " + t1.equals(t2));
		System.out.println("t2 equal to t3? " + t1.equals(t3));
		System.out.println("t1 equal to t3? " + t1.equals(t3));
		
		System.out.println("\nReflexive: t1 equal to t1? " + t1.equals(t1));
		
		System.out.println("\nt1 equal to null? " + t1.equals(null));
	}
}
