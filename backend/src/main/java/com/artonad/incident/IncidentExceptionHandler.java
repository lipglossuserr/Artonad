package com.artonad.incident;

import com.fasterxml.jackson.databind.exc.InvalidFormatException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.Arrays;
import java.util.stream.Collectors;

/**
 * Turns errors into the contract format { "error": "...", "message": "..." }.
 * Scoped to IncidentController so it cannot clash with Dev2's global handler on merge day.
 */
@RestControllerAdvice(assignableTypes = IncidentController.class)
@Order(Ordered.HIGHEST_PRECEDENCE)
public class IncidentExceptionHandler {

    public record ErrorBody(String error, String message) {}

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorBody> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .sorted()
                .collect(Collectors.joining("; "));
        return badRequest(message);
    }

    /** Bad JSON, or a value of the wrong type (e.g. "type": "FLOOD"). */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorBody> handleUnreadable(HttpMessageNotReadableException ex) {
        String message = "Request body is missing or malformed";
        if (ex.getCause() instanceof InvalidFormatException ife && !ife.getPath().isEmpty()) {
            String field = ife.getPath().get(ife.getPath().size() - 1).getFieldName();
            message = ife.getTargetType().isEnum()
                    ? field + " must be one of " + Arrays.toString(ife.getTargetType().getEnumConstants())
                    : field + " has an invalid value: " + ife.getValue();
        }
        return badRequest(message);
    }

    /** e.g. GET /incidents/abc */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorBody> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        return badRequest(ex.getName() + " has an invalid value: " + ex.getValue());
    }

    @ExceptionHandler(IncidentNotFoundException.class)
    public ResponseEntity<ErrorBody> handleNotFound(IncidentNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorBody("NOT_FOUND", ex.getMessage()));
    }

    private ResponseEntity<ErrorBody> badRequest(String message) {
        return ResponseEntity.badRequest().body(new ErrorBody("VALIDATION_FAILED", message));
    }
}
