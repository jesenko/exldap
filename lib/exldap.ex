defmodule Exldap do

  @doc ~S"""
  Connects to a LDAP server using the settings defined in config.exs

  ## Example

      iex> Exldap.connect
      {:ok, connection}
      Or
      {:error, error_description}

  """
  def connect do
    settings = Application.get_env :exldap, :settings

    server = settings |> Dict.get(:server)
    port = settings |> Dict.get(:port)
    ssl = settings |> Dict.get(:ssl)
    user_dn = settings |> Dict.get(:user_dn)
    password = settings |> Dict.get(:password)

    connect(server, port, ssl, user_dn, password)
  end


  @doc ~S"""
  Connects to a LDAP server using the arguments passed into the function

  ## Example

      iex> Exldap.connect("SERVERADDRESS", 636, true, "CN=test123,OU=Accounts,DC=example,DC=com", "PASSWORD")
      {:ok, connection}
      Or
      {:error, error_description}

  """
  def connect(server, port, ssl, user_dn, password) when is_binary(server) do
    connect :erlang.binary_to_list(server), port, ssl, user_dn, password
  end

  def connect(server, port, ssl, user_dn, password) do

    case open(server, port, ssl) do
      {:ok, connection} ->
        case verify_credentials(connection, user_dn, password) do
          :ok -> {:ok, connection}
          {_, message} -> {:error, message}
        end
      error -> error
    end

  end

  @doc ~S"""
  Open a connection to the LDAP server using the settings defined in config.exs

  ## Example

      iex> Exldap.open
      {:ok, connection}
      Or
      {:error, error_description}

  """
  def open do
    settings = Application.get_env :exldap, :settings

    server = settings |> Dict.get(:server)
    port = settings |> Dict.get(:port)
    ssl = settings |> Dict.get(:ssl)

    open(server, port, ssl)
  end

  @doc ~S"""
  Open a connection to the LDAP server

  ## Example

      iex> Exldap.open("SERVERADDRESS", 636, true)
      {:ok, connection}
      Or
      {:error, error_description}

  """
  def open(server, port, ssl) when is_binary(server) do
      open(:erlang.binary_to_list(server), port, ssl)
  end

  def open(server, port, ssl) do
    :eldap.open([server], [{:port, port},{:ssl, ssl}])
  end

  @doc ~S"""
  Shutdown a connection to the LDAP server

  ## Example

      iex> Exldap.close(connection)

  """
  def close(connection) do
    :eldap.close(connection)
  end

  @doc ~S"""
  Verify the credentials against a LDAP connection

  ## Example

      iex> Exldap.verify_credentials(connection, "CN=test123,OU=Accounts,DC=example,DC=com", "PASSWORD")
      :ok --> Successfully connected
      Or
      {:error, :invalidCredentials} --> Failed to connect

  """
  def verify_credentials(connection, user_dn, password) when is_binary(user_dn) and is_binary(password) do
    verify_credentials connection, :erlang.binary_to_list(user_dn), :erlang.binary_to_list(password)
  end

  def verify_credentials(connection, user_dn, password) when is_list(user_dn) and is_binary(password) do
    verify_credentials connection, user_dn, :erlang.binary_to_list(password)
  end
  def verify_credentials(connection, user_dn, password) when is_binary(user_dn) and is_list(password) do
    verify_credentials connection, :erlang.binary_to_list(user_dn), password
  end

  def verify_credentials(connection, user_dn, password) do
    :eldap.simple_bind(connection, user_dn, password)
  end

  @doc ~S"""
  Searches for a LDAP entry, the base dn is obtained from the config.exs

  ## Example

      iex> Exldap.search_field(connection, "cn", "useraccount")
      {:ok, search_results}

  """
  def search_field(connection, field, name) do
    settings = Application.get_env :exldap, :settings
    base_config = settings |> Dict.get(:base)
    search_field(connection, base_config, field, name)
  end


  @doc ~S"""
  Searches for a LDAP entry using the arguments passed into the function

  ## Example

      iex> Exldap.search_field(connection, "OU=Accounts,DC=example,DC=com", "cn", "useraccount")
      {:ok, search_results}

  """
  def search_field(connection, base, field, name) when is_list(name) do
    search_field connection, base, field, :erlang.list_to_binary(name)
  end

  def search_field(connection, base, field, name) do
    filter = {:filter, :eldap.equalityMatch(field, name)}
    base_config = {:base, base}
    scope = {:scope, :eldap.wholeSubtree()}
    search = [base_config, scope, filter]

    case :eldap.search(connection, search) do
      {:ok, result} ->
        result = Exldap.SearchResult.from_record(result)
        {:ok, result.entries |> Enum.map(fn(x) -> Exldap.Entry.from_record(x) end)}
      {_, message} -> {:error, message}
    end

  end

  @doc ~S"""
  Searches a LDAP entry and extracts an attribute based on the specified key, if the attribute does not exist returns nil

  ## Example

      iex> Exldap.search_attributes(first_result, "displayName")
      "Test User"

  """
  def search_attributes(%Exldap.Entry{} = entry, key) when is_binary(key) do
    search_attributes(entry, :erlang.binary_to_list(key))
  end

  def search_attributes(%Exldap.Entry{} = entry, key) when is_list(key) do
    if List.keymember?(entry.attributes, key, 0) do
      {_, value} = List.keyfind(entry.attributes, key, 0)
      :erlang.list_to_binary(value)
    else
      nil
    end
  end

end
