
package com.artonad.backend.responder;

import jakarta.persistence.*;

@Entity
@Table(name = "responders")
public class Responder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "name")
    private String name;

    @Column(name = "role")
    private String role;

    @Column(name = "available")
    private boolean available;

    @Column(name = "lat")
    private Double lat;

    @Column(name = "lng")
    private Double lng;

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getRole() {
        return role;
    }

    public boolean isAvailable() {
        return available;
    }

    public Double getLat() {
        return lat;
    }

    public Double getLng() {
        return lng;
    }
}
