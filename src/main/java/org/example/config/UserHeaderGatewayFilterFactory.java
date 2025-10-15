package org.example.config;

import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.factory.AbstractGatewayFilterFactory;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;

@Component
public class UserHeaderGatewayFilterFactory extends AbstractGatewayFilterFactory<Object>{

    @Override
    public GatewayFilter apply(Object config) {
        return (exchange, chain) -> ReactiveSecurityContextHolder.getContext()
                .map(securityContext -> securityContext.getAuthentication())
                .cast(JwtAuthenticationToken.class)
                .map(auth -> {
                    Jwt jwt = auth.getToken();

                    // Extract roles from Spring Security authorities (already converted by JwtAuthConverter)
                    String roles = auth.getAuthorities().stream()
                            .map(Object::toString)
                            .reduce((a, b) -> a + "," + b)
                            .orElse("");

                    // Add user information as headers
                    ServerWebExchange modifiedExchange = exchange.mutate()
                            .request(r -> r
                                    .header("X-User-Id", jwt.getSubject())
                                    .header("X-User-Name", jwt.getClaimAsString("preferred_username"))
                                    .header("X-User-Email", jwt.getClaimAsString("email"))
                                    .header("X-User-FirstName", jwt.getClaimAsString("given_name"))
                                    .header("X-User-LastName", jwt.getClaimAsString("family_name"))
                                    .header("X-User-Roles", roles)
                            )
                            .build();

                    return modifiedExchange;
                })
                .defaultIfEmpty(exchange)
                .flatMap(chain::filter);
    }
}
