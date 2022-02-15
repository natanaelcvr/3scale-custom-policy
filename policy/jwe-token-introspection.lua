local policy = require('apicast.policy')
local _M = policy.new('JWEIntrospectionPolicy')

local cjson = require('cjson.safe')
local http_authorization = require 'resty.http_authorization'
local http_ng = require 'resty.http_ng'
local user_agent = require 'apicast.user_agent'
local resty_env = require('resty.env')
local resty_url = require('resty.url')

local tokens_cache = require('tokens_cache')

local tonumber = tonumber

local new = _M.new

local noop = function() end
local noop_cache = { get = noop, set = noop }

local function create_credential(client_id, client_secret)
  return 'Basic ' .. ngx.encode_base64(table.concat({ client_id, client_secret }, ':'))
end

function _M.new(config)
  local self = new(config)
  self.config = config or {}
  self.auth_type = config.auth_type or "client_id+client_secret"
  --- authorization for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.2
  if self.auth_type == "client_id+client_secret" then
    self.credential = create_credential(self.config.client_id or '', self.config.client_secret or '')
    self.introspection_url = config.introspection_url
  end
  self.http_client = http_ng.new{
    backend = config.client,
    options = {
      headers = {
        ['User-Agent'] = user_agent()
      },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }

  local max_cached_tokens = tonumber(config.max_cached_tokens) or 0
  self.caching_enabled = max_cached_tokens > 0

  if self.caching_enabled then
    self.tokens_cache = tokens_cache.new(
      config.max_ttl_tokens, config.max_cached_tokens)
  else
    self.tokens_cache = noop_cache
  end

  return self
end

--- OAuth 2.0 Token Introspection defined in RFC7662.
-- https://tools.ietf.org/html/rfc7662
local function introspect_token(self, token)
  local cached_token_info = self.tokens_cache:get(token)
  if cached_token_info then return cached_token_info end

  --- Parameters for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.1
  local res, err = self.http_client.post{self.introspection_url , { token = token, token_type_hint = 'access_token'},
    headers = {['Authorization'] = self.credential}}
  if err then
    ngx.log(ngx.WARN, 'token introspection error: ', err, ' url: ', self.introspection_url)
    return { active = false }
  end

  if res.status == 200 then
    local token_info, decode_err = cjson.decode(res.body)
    if type(token_info) == 'table' then
      self.tokens_cache:set(token, token_info)
      return token_info
    else
      ngx.log(ngx.ERR, 'failed to parse token introspection response:', decode_err)
      return { active = false }
    end
  else
    ngx.log(ngx.WARN, 'failed to execute token introspection. status: ', res.status)
    return { active = false }
  end
end

function _M:access(context)
  if self.auth_type == "use_3scale_oidc_issuer_endpoint" then
    if not context.proxy.oauth then
      ngx.status = context.service.auth_failed_status
      ngx.say(context.service.error_auth_failed)
      return ngx.exit(ngx.status)
    end

    local components = resty_url.parse(context.service.oidc.issuer_endpoint)
    self.credential = create_credential(components.user, components.password)
    self.introspection_url = context.proxy.oauth.config.token_introspection_endpoint
  end

  if self.introspection_url then
    local authorization = http_authorization.new(ngx.var.http_authorization)
    local access_token = authorization.token
    --- Introspection Response must have an "active" boolean value.
    -- https://tools.ietf.org/html/rfc7662#section-2.2
    if not introspect_token(self, access_token).active == true then
      ngx.log(ngx.INFO, 'token introspection for access token ', access_token, ': token not active')
      ngx.status = context.service.auth_failed_status
      ngx.say(context.service.error_auth_failed)
      return ngx.exit(ngx.status)
    end

    ngx.log(ngx.INFO, 'hello do ramalho setando uma variavel no contexto')
    context.jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgICJhY3RpdmUiOiB0cnVlLCAgICJzZXJ2ZXJfaW5mbyI6IHsgICAgICAgImlkX3NlcnZpZG9yIjogImR4bDFvYXQwMDAwOF9vYXQtc2Vydmlkb3ItYXV0b3JpemFjYW8tMiIsICAgICAgICJ2ZXJzaW9uIjogIjEuMTEuMzQuMi1TTkFQU0hPVCIsICAgICAgICJpcCI6ICJkeGwxb2F0MDAwMDguZGlzcG9zaXRpdm9zLmJiLmNvbS5ici8xNzIuMjAuMjQ0LjMiICAgfSwgICAiaXNzIjogImh0dHBzOi8vb2F1dGguYmIuY29tLmJyL29hdXRoIiwgICAianRpIjogIjZkZmVlZjUyLWU0ZGItNDBjYS05ODYxLTE0YjBhYWJlYWY3ZCIsICAgImNsaWVudF9pZCI6ICJleUpwWkNJNkltVXhZMkUxTURJdE1qVWlMQ0pqYjJScFoyOVFkV0pzYVdOaFpHOXlJam93TENKamIyUnBaMjlUYjJaMGQyRnlaU0k2TWpBeExDSnpaWEYxWlc1amFXRnNTVzV6ZEdGc1lXTmhieUk2TlRGOSIsICAgImlhdCI6IDE2NDI2MDMzMDEwMDEsICAgImV4cCI6IDI2NDI2MDMzMDAwMDEsICAgImdyYW50X3R5cGUiOiAiY2xpZW50X2NyZWRlbnRpYWxzIiwgICAic3ViIjogImV5SnBaQ0k2SW1VeFkyRTFNREl0TWpVaUxDSmpiMlJwWjI5UWRXSnNhV05oWkc5eUlqb3dMQ0pqYjJScFoyOVRiMlowZDJGeVpTSTZNakF4TENKelpYRjFaVzVqYVdGc1NXNXpkR0ZzWVdOaGJ5STZOVEY5IiwgICAiYXVkIjogImh0dHBzOi8vb2F1dGguYmIuY29tLmJyL29hdXRoIGh0dHBzOi8vYXBpLmJiLmNvbS5ici8iLCAgICJzY29wZSI6ICJiYi5hcGktcHJpdmF0aXZhLnJlc3RyaXRhLmFyaCBlbWFpbCBjcGYiLCAgICJzZWNyZXRfZmllbGRzIjoge30sICAgInB1YmxpY19maWVsZHMiOiB7ICAgICAgICJjb2RpZ29fcHVibGljYWRvciI6ICIxNzY5ODkwOTkiLCAgICAgICAiY2lkIjogIjIwMjIwMTE5MTE0MTQxLTk4YTljYTRjLTY5ZmItNGRhZS04MzBmLWVmNGVmMGI1ZTgxNyIgICB9fQ==.jKINuYmO3SIsPFhOsnukJG3tHuBgDQey4QUXG7VYByhTVaIenfFFTA9IoX63LWyEarCE2NJ7Q7jtQMhAlMzRSA'
  end
end

return _M
