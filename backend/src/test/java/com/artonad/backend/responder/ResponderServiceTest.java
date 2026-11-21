package com.artonad.backend.responder;

import org.junit.jupiter.api.Test;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ResponderServiceTest {

    @Test
    void shouldReturnEmptyListWhenNoRespondersExist() {

        ResponderRepository repository = mock(ResponderRepository.class);

        when(repository.findAll()).thenReturn(List.of());

        ResponderService service = new ResponderService(repository);

        List<Responder> result = service.getAllResponders();

        assertNotNull(result);
        assertTrue(result.isEmpty());

        verify(repository, times(1)).findAll();
    }

    @Test
    void shouldReturnRespondersWhenTheyExist() {

        ResponderRepository repository = mock(ResponderRepository.class);

        Responder responder = mock(Responder.class);

        when(repository.findAll()).thenReturn(List.of(responder));

        ResponderService service = new ResponderService(repository);

        List<Responder> result = service.getAllResponders();

        assertEquals(1, result.size());
        assertSame(responder, result.get(0));

        verify(repository, times(1)).findAll();
    }
}