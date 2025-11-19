# Start Credo application for Credo check tests
Application.ensure_all_started(:credo)

ExUnit.start()
