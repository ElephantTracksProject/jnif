package frheapagent;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public class HeapTest {

	int something(long l) {
		return 42;
	}

	int hola(int a, int b) {
		int c = a + b;
		return c;
	}

	double dhola(double a) {
		double b = 2;
		double c = a + b;
		return c;
	}

	public static void main(String[] args) throws IOException {
		int[] as = new int[34];

		for (int i = 0; i < as.length; i++) {
			as[i] = i;
		}
		;

		System.out.println("HeapTest: " + as[as.length - 1]);
	}
}
