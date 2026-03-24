defprotocol CQRS.Certifiable do
  @spec certify(t) :: :ok | {:error, Keyword.t()}
  def certify(t)
end
