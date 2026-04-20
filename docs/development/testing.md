# Testing

Testing and quality assurance in ATLAS.

## Overview

TODO: Document testing strategy

ATLAS uses:
- Unit tests for individual modules
- Integration tests for components
- End-to-end tests for workflows
- Regression tests for known issues

## Running Tests

### Run All Tests

```bash
cd build
ctest
```

### Run with Verbose Output

```bash
ctest --output-on-failure
```

### Run Specific Tests

```bash
ctest -R "test_pattern" --output-on-failure
```

### Run in Parallel

```bash
ctest -j 4 --output-on-failure
```

## Test Organization

```
test/
├── BCB/                 # BCB component tests
│   ├── test_bc_mod.f90
│   └── CMakeLists.txt
├── ICB/                 # ICB component tests
│   ├── test_ic_mod.f90
│   └── CMakeLists.txt
├── KAnT/                # KAnT tests
├── 1D/, 2D/, 3D/       # Dimensional test cases
├── common/              # Shared test utilities
└── test.sh              # Test runner script
```

## Writing Tests

TODO: Document test writing guidelines

### Test Template (Fortran)

```fortran
program test_my_module
  use my_module
  implicit none
  
  logical :: tests_passed
  
  tests_passed = .true.
  
  ! Test 1
  if (test_function() /= expected_value) then
    print *, "FAIL: Test 1"
    tests_passed = .false.
  else
    print *, "PASS: Test 1"
  end if
  
  if (tests_passed) then
    stop 0  ! Success
  else
    stop 1  ! Failure
  end if
end program test_my_module
```

### Adding Tests to CMake

In `test/CMakeLists.txt`:

```cmake
add_executable(test_my_module test_my_module.f90)
target_link_libraries(test_my_module atlas_lib)

add_test(
  NAME MyModuleTest
  COMMAND test_my_module
)
```

## Test Categories

### Unit Tests
- Test individual modules/functions
- Fast execution
- Location: `test/*/test_*.f90`

### Integration Tests
- Test component interactions
- Location: `test/*/test_integration_*.f90`

### Regression Tests
- Known issues and fixes
- Location: `test/regression/`

### Performance Tests
- Performance benchmarks
- Location: `test/performance/`

## Continuous Integration

TODO: Document CI/CD setup

- Runs on: Every push and pull request
- Status: Shown in GitHub PR
- Logs: Available in GitHub Actions

### Local CI Check

Before pushing, run:

```bash
# Build and test
cd build
cmake ..
make -j 4
ctest --output-on-failure
```

## Test Measurement

### Code Coverage

TODO: Document coverage measurement

```bash
# Build with coverage
cmake -DENABLE_COVERAGE=ON ..
make
ctest
# Generate coverage report
```

### Performance Benchmarks

TODO: Document benchmark methods

```bash
# Run performance tests
ctest -R performance --output-on-failure
```

## Troubleshooting Tests

### Test Fails Locally

1. Check build configuration
2. Verify all dependencies
3. Check test logs for errors
4. Review recent changes

### Test Output

Tests produce output in:
- `build/Testing/` directory
- Console output (with `-VV` flag)
- Log files (if configured)

```bash
# Verbose output
ctest -VV --output-on-failure

# Save results
ctest --output-on-failure > test_results.txt
```

## Best Practices

- ✓ Write tests for new features
- ✓ Run tests before committing
- ✓ Fix failing tests immediately
- ✓ Keep tests fast and focused
- ✓ Document complex test logic
- ✗ Don't skip failing tests
- ✗ Don't commit broken tests

## Adding Test Cases

TODO: Document adding new test cases

1. Create test source file: `test/component/test_feature.f90`
2. Add to `test/component/CMakeLists.txt`
3. Run locally: `ctest -R feature_test`
4. Commit: Include test with feature

---

See: [Build Instructions](./build), [Code Style](./code-style)
