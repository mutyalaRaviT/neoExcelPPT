#!/usr/bin/env python3
"""
Test runner script for NeoExcelPPT Playwright tests.

Usage:
    # Run all tests
    python run_tests.py

    # Run specific test file
    python run_tests.py test_simple.py

    # Run with visible browser
    python run_tests.py --headed

    # Run specific test
    python run_tests.py -k "test_homepage_loads"

    # Run against different URL
    TEST_BASE_URL=http://localhost:4002 python run_tests.py
"""

import subprocess
import sys
import os

def main():
    # Change to test directory
    test_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(test_dir)

    # Build pytest command
    cmd = [
        sys.executable, "-m", "pytest",
        "-v",  # Verbose output
        "--tb=short",  # Short traceback
    ]

    # Add any additional arguments passed to script
    cmd.extend(sys.argv[1:])

    # If no test file specified, run all
    if not any(arg.endswith('.py') for arg in sys.argv[1:]):
        cmd.append(".")

    print(f"Running: {' '.join(cmd)}")
    print(f"Base URL: {os.environ.get('TEST_BASE_URL', 'http://localhost:4000')}")
    print("-" * 60)

    # Run tests
    result = subprocess.run(cmd)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
