module Oauth
  # Descoberta (o cliente lê isto para saber onde autorizar e trocar tokens):
  #   /.well-known/oauth-protected-resource   (RFC 9728) — sobre o servidor MCP
  #   /.well-known/oauth-authorization-server (RFC 8414) — sobre o login OAuth
  class MetadataController < ActionController::API
    include Oauth::Cors

    def protected_resource
      render json: {
        resource: mcp_url,
        authorization_servers: [root_url.chomp("/")],
        bearer_methods_supported: ["header"],
        scopes_supported: [OauthGrant::SCOPE],
        resource_name: "Life"
      }
    end

    def authorization_server
      render json: {
        issuer: root_url.chomp("/"),
        authorization_endpoint: oauth_authorize_url,
        token_endpoint: oauth_token_url,
        registration_endpoint: oauth_register_url,
        revocation_endpoint: oauth_revoke_url,
        response_types_supported: ["code"],
        grant_types_supported: %w[authorization_code refresh_token],
        code_challenge_methods_supported: ["S256"],
        token_endpoint_auth_methods_supported: ["none"],
        scopes_supported: [OauthGrant::SCOPE],
        client_id_metadata_document_supported: true
      }
    end
  end
end
