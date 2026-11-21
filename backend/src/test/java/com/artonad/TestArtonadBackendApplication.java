package com.artonad;

import org.springframework.boot.SpringApplication;

public class TestArtonadBackendApplication {

	public static void main(String[] args) {
		SpringApplication.from(ArtonadBackendApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
