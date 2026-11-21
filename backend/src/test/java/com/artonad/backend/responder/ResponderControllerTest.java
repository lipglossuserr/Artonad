package com.artonad.backend.responder;

import org.junit.jupiter.api.Test;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ResponderControllerTest {

    @Test
    void shouldReturnEmptyListWhenNoRespondersExist() {

        ResponderService service = mock(ResponderService.class);

        when(service.getAllResponders()).thenReturn(List.of());

        ResponderController controller = new ResponderController(service);

        List<ResponderResponse> result = controller.getResponders();

        assertNotNull(result);
        assertTrue(result.isEmpty());

        verify(service, times(1)).getAllResponders();
    }
}