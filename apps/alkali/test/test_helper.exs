# Start ExUnit
ExUnit.start()

# Configure ExUnit
ExUnit.configure(
  exclude: [:pending],
  formatters: [ExUnit.CLIFormatter]
)

# Configure and compile Cucumber features
Cucumber.compile_features!()
