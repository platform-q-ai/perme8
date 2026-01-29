# This file contains the configuration for Credo and you are probably reading
# this after creating it with `mix credo.gen.config`.
#
# If you find anything wrong or unclear in this file, please report an
# issue on GitHub: https://github.com/rrrene/credo/issues
#
%{
  #
  # You can have as many configs as you like in the `configs:` field.
  configs: [
    %{
      #
      # Run any config using `mix credo -C <name>`. If no config name is given
      # "default" is used.
      #
      name: "default",
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/",
          "apps/*/mix.exs"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      #
      # Load and configure plugins here:
      #
      plugins: [],
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      #
      requires: [
        ".credo/checks/no_direct_repo_in_web.ex",
        ".credo/checks/no_business_logic_in_live_view.ex",
        ".credo/checks/no_pubsub_in_contexts.ex",
        ".credo/checks/no_broadcast_in_transaction.ex",
        ".credo/checks/no_database_queries_in_live_views.ex",
        ".credo/checks/no_infrastructure_in_policies.ex",
        ".credo/checks/no_business_logic_in_schemas.ex",
        ".credo/checks/no_direct_queries_in_use_cases.ex",
        ".credo/checks/use_case_adoption.ex",
        ".credo/checks/missing_domain_tests.ex",
        ".credo/checks/domain_test_purity.ex",
        ".credo/checks/no_inline_queries_in_contexts.ex",
        ".credo/checks/no_repo_in_services.ex",
        ".credo/checks/no_cross_context_policy_access.ex",
        ".credo/checks/no_cross_context_schema_access.ex",
        ".credo/checks/missing_queries_module.ex",
        # Clean Code Principle Checks
        ".credo/checks/no_repo_in_domain.ex",
        ".credo/checks/no_side_effects_in_domain.ex",
        ".credo/checks/no_env_in_runtime.ex",
        # Folder structure enforcement checks
        ".credo/checks/entities_in_domain_layer.ex",
        ".credo/checks/use_cases_in_application_layer.ex",
        ".credo/checks/policies_in_application_layer.ex",
        ".credo/checks/services_in_correct_layer.ex",
        ".credo/checks/infrastructure_organization.ex",
        # Refactoring enforcement checks
        ".credo/checks/no_ecto_in_domain_layer.ex",
        ".credo/checks/no_direct_repo_in_use_cases.ex",
        ".credo/checks/application_layer_infrastructure_dependency.ex",
        ".credo/checks/no_io_in_domain_services.ex",
        # Clean Architecture layer boundary checks
        ".credo/checks/no_infrastructure_in_domain_entities.ex",
        ".credo/checks/no_direct_file_operations_in_use_cases.ex",
        ".credo/checks/interface_layer_uses_public_api.ex",
        # Domain purity and testability checks
        ".credo/checks/no_datetime_now_in_domain.ex",
        ".credo/checks/no_infrastructure_schema_in_web.ex",
        ".credo/checks/no_application_config_in_use_cases.ex",
        # Boundary library enforcement checks
        ".credo/checks/boundary_package_installed.ex",
        ".credo/checks/architectural_layers_defined.ex",
        ".credo/checks/boundary_enforcement_configured.ex",
        ".credo/checks/clean_architecture_boundary_rules.ex"
      ],
      #
      # If you want to enforce a style guide and need a more traditional linting
      # experience, you can change `strict` to `true` below:
      #
      strict: false,
      #
      # To modify the timeout for parsing files, change this value:
      #
      parse_timeout: 5000,
      #
      # If you want to use uncolored output by default, you can change `color`
      # to `false` below:
      #
      color: true,
      #
      # You can customize the parameters of any check by adding a second element
      # to the tuple.
      #
      # To disable a check put `false` as second element:
      #
      #     {Credo.Check.Design.DuplicatedCode, false}
      #
      checks: %{
        enabled: [
          #
          ## Consistency Checks
          #
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          #
          ## Design Checks
          #
          # You can customize the priority of any check
          # Priority values are: `low, normal, high, higher`
          #
          {Credo.Check.Design.AliasUsage,
           [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagFIXME, []},
          # You can also customize the exit_status of each check.
          # If you don't want TODO comments to cause `mix credo` to fail, just
          # set this value to 0 (zero).
          #
          {Credo.Check.Design.TagTODO, [exit_status: 2]},

          #
          ## Readability Checks
          #
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          #
          ## Refactoring Opportunities
          #
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          #
          ## Warnings
          #
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},

          #
          ## Custom Architectural Checks
          #
          # These checks enforce Clean Architecture, SOLID principles, and TDD practices
          # as defined in CLAUDE.md
          #
          {Credo.Check.Custom.Architecture.NoDirectRepoInWeb, []},
          {Credo.Check.Custom.Architecture.NoBusinessLogicInLiveView, []},
          {Credo.Check.Custom.Architecture.NoPubSubInContexts, []},
          {Credo.Check.Custom.Architecture.NoBroadcastInTransaction, []},
          {Credo.Check.Custom.Architecture.NoDatabaseQueriesInLiveViews, []},
          # Detect infrastructure (DB queries) in domain Policy modules
          {Credo.Check.Custom.Architecture.NoInfrastructureInPolicies, []},
          # Detect business logic in Ecto schemas (SRP violation)
          {Credo.Check.Custom.Architecture.NoBusinessLogicInSchemas, []},
          # Detect direct Ecto queries in UseCase modules
          {Credo.Check.Custom.Architecture.NoDirectQueriesInUseCases, []},
          # Detect complex orchestration logic that should be extracted to use cases
          {Credo.Check.Custom.Architecture.UseCaseAdoption, [with_clause_threshold: 3]},
          # Detect inline Ecto queries in contexts instead of Query objects
          {Credo.Check.Custom.Architecture.NoInlineQueriesInContexts, []},
          # Detect direct Repo access in Service modules
          {Credo.Check.Custom.Architecture.NoRepoInServices, []},
          # Detect cross-context Policy access (should use context public API)
          {Credo.Check.Custom.Architecture.NoCrossContextPolicyAccess, []},
          # Detect cross-context Schema access (should use context public API)
          {Credo.Check.Custom.Architecture.NoCrossContextSchemaAccess, []},
          # Detect contexts missing Queries modules (pattern consistency)
          # Disabled: Queries modules are optional based on context needs
          # {Credo.Check.Custom.Architecture.MissingQueriesModule, []},

          #
          ## Clean Code Principle Checks
          #
          # These checks enforce clean code principles identified in code reviews
          #
          # Detect Repo or database dependencies in domain entities (DIP violation)
          {Credo.Check.Custom.Architecture.NoRepoInDomain, []},
          # Detect side effects (crypto, I/O) in domain entities (SRP violation)
          {Credo.Check.Custom.Architecture.NoSideEffectsInDomain, []},
          # Detect runtime env variable access that should use Application config
          {Credo.Check.Custom.Architecture.NoEnvInRuntime, []},

          #
          ## Folder Structure Enforcement
          #
          # Detect entities (Ecto schemas) not in domain/entities/ subdirectory
          # DISABLED: Conflicts with Clean Architecture refactoring where Ecto schemas
          # are intentionally in infrastructure/schemas/, not domain/entities/
          # {Credo.Check.Custom.Architecture.EntitiesInDomainLayer, []},
          # Detect use cases not in application/use_cases/ subdirectory
          {Credo.Check.Custom.Architecture.UseCasesInApplicationLayer, []},
          # Detect policies not in application/policies/ subdirectory
          {Credo.Check.Custom.Architecture.PoliciesInApplicationLayer, []},
          # Detect services/notifiers in wrong layers
          {Credo.Check.Custom.Architecture.ServicesInCorrectLayer, []},
          # Detect infrastructure files not properly organized
          {Credo.Check.Custom.Architecture.InfrastructureOrganization, []},

          #
          ## Refactoring Enforcement (Agents Context Violations)
          #
          # These checks catch violations from the Agents Context Refactoring Proposal
          #
          # Detect Ecto dependencies in domain layer (domain entities should be pure structs)
          {Credo.Check.Custom.Architecture.NoEctoInDomainLayer, []},
          # Detect direct Repo usage in use cases (should delegate to repositories)
          {Credo.Check.Custom.Architecture.NoDirectRepoInUseCases, []},
          # Detect I/O operations in application layer (should be in infrastructure)
          {Credo.Check.Custom.Architecture.ApplicationLayerInfrastructureDependency, []},
          # Detect I/O operations in domain services (should be pure functions)
          {Credo.Check.Custom.Architecture.NoIoInDomainServices, []},
          # Detect infrastructure calls in domain entities (dependency rule violation)
          {Credo.Check.Custom.Architecture.NoInfrastructureInDomainEntities, []},
          # Detect direct File operations in use cases (should use injectable deps)
          {Credo.Check.Custom.Architecture.NoDirectFileOperationsInUseCases, []},
          # Detect Mix tasks bypassing public API (interface layer violation)
          {Credo.Check.Custom.Architecture.InterfaceLayerUsesPublicApi, []},
          # Detect non-deterministic DateTime calls in domain layer
          {Credo.Check.Custom.Architecture.NoDateTimeNowInDomain, []},
          # Detect infrastructure schema access from web layer
          {Credo.Check.Custom.Architecture.NoInfrastructureSchemaInWeb, []},
          # Detect Application.get_env in use cases (should use dependency injection)
          {Credo.Check.Custom.Architecture.NoApplicationConfigInUseCases, []},

          #
          ## Boundary Library Enforcement
          #
          # Comprehensive check: verifies boundary package, compiler, and usage
          # This replaces separate checks for package installation and layer files
          {CredoChecks.CleanArchitecture.BoundaryEnforcementConfigured, []},
          # Verifies that boundary `deps` follow Clean Architecture rules
          # (Domain has no deps, Application only depends on Domain, etc.)
          {CredoChecks.CleanArchitecture.BoundaryRules, []},

          #
          ## Custom Testing Checks (TDD Enforcement)
          #
          # These checks enforce TDD practices and test pyramid structure
          #
          # Detect missing tests for domain modules (policies, services)
          {Credo.Check.Custom.Testing.MissingDomainTests, []},
          # Detect domain tests incorrectly using DataCase instead of ExUnit.Case
          {Credo.Check.Custom.Testing.DomainTestPurity, []}
        ],
        disabled: [
          #
          # Checks scheduled for next check update (opt-in for now)
          {Credo.Check.Refactor.UtcNowTruncate, []},

          #
          # Controversial and experimental checks (opt-in, just move the check to `:enabled`
          #   and be sure to use `mix credo --strict` to see low priority checks)
          #
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.OnePipePerLine, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.ABCSize, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.VariableRebinding, []},
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, []}

          # {Credo.Check.Refactor.MapInto, []},

          #
          # Custom checks can be created using `mix credo.gen.check`.
          #
        ]
      }
    }
  ]
}
