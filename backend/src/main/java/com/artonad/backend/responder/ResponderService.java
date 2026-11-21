package com.artonad.backend.responder;

import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ResponderService {

    private final ResponderRepository responderRepository;

    public ResponderService(ResponderRepository responderRepository) {
        this.responderRepository = responderRepository;
    }

    public List<Responder> getAllResponders() {
        return responderRepository.findAll();
    }
}
