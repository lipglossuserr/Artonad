
package com.artonad.backend.responder;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/responders")
public class ResponderController {

    private final ResponderService responderService;

    public ResponderController(ResponderService responderService) {
        this.responderService = responderService;
    }

    @GetMapping
    public List<ResponderResponse> getResponders() {
        return responderService.getAllResponders().stream()
            .map(responder -> new ResponderResponse(
                responder.getId(),
                responder.getName(),
                responder.getRole(),
                responder.isAvailable(),
                new ResponderResponse.LocationResponse(
                    responder.getLat(),
                    responder.getLng()
                )
            ))
            .toList();
    }
}
