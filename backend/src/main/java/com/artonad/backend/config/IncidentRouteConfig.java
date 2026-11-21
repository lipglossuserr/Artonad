
package com.artonad.backend.config;

import com.artonad.incident.IncidentController;
import com.artonad.incident.dto.CreateIncidentRequest;

import jakarta.annotation.PostConstruct;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import java.lang.reflect.Method;

@Configuration
public class IncidentRouteConfig {

    private final RequestMappingHandlerMapping handlerMapping;
    private final IncidentController incidentController;

    public IncidentRouteConfig(
            @Qualifier("requestMappingHandlerMapping")
            RequestMappingHandlerMapping handlerMapping,
            IncidentController incidentController) {

        this.handlerMapping = handlerMapping;
        this.incidentController = incidentController;
    }

    @PostConstruct
    public void registerIncidentRoutes() throws NoSuchMethodException {

        register(
                "create",
                "/api/v1/incidents",
                RequestMethod.POST,
                CreateIncidentRequest.class
        );

        register(
                "list",
                "/api/v1/incidents",
                RequestMethod.GET
        );

        register(
                "get",
                "/api/v1/incidents/{id}",
                RequestMethod.GET,
                long.class
        );
    }

    private void register(
            String methodName,
            String path,
            RequestMethod requestMethod,
            Class<?>... parameterTypes) throws NoSuchMethodException {

        Method method = IncidentController.class
                .getMethod(methodName, parameterTypes);

        RequestMappingInfo mapping = RequestMappingInfo
                .paths(path)
                .methods(requestMethod)
                .options(handlerMapping.getBuilderConfiguration())
                .build();

        handlerMapping.registerMapping(
                mapping,
                incidentController,
                method
        );
    }
}
