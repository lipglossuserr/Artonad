package com.artonad.incident;

public class IncidentAccessDeniedException extends RuntimeException {
    public IncidentAccessDeniedException() {
        super("You can only view incidents that you reported");
    }
}