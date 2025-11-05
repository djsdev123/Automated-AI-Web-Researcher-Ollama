"""
Configuration Loader for Automated AI Web Researcher
Loads YAML configuration with environment variable substitution
Provides backward compatibility with legacy llm_config.py
"""

import yaml
import os
import re
import logging
from typing import Any, Dict, Optional
from pathlib import Path

logger = logging.getLogger(__name__)


class ConfigLoader:
    """Load and manage application configuration"""

    DEFAULT_CONFIG_PATH = "/app/config/config.yaml"
    LEGACY_CONFIG_MODULE = "llm_config"

    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize configuration loader

        Args:
            config_path: Path to YAML config file. If None, uses default locations.
        """
        self.config_path = config_path or os.getenv('CONFIG_PATH', self.DEFAULT_CONFIG_PATH)
        self._config = None
        self._legacy_mode = False

    def load(self) -> Dict[str, Any]:
        """
        Load configuration from YAML file with fallback to legacy config

        Returns:
            Dictionary containing full configuration
        """
        # Try loading YAML config first
        if os.path.exists(self.config_path):
            try:
                self._config = self._load_yaml_config(self.config_path)
                logger.info(f"Loaded configuration from {self.config_path}")
                return self._config
            except Exception as e:
                logger.warning(f"Failed to load YAML config: {e}")

        # Fallback to legacy llm_config.py
        logger.info("YAML config not found, attempting legacy config migration")
        self._config = self._load_legacy_config()
        self._legacy_mode = True

        return self._config

    def _load_yaml_config(self, config_path: str) -> Dict[str, Any]:
        """Load YAML config and substitute environment variables"""
        with open(config_path, 'r') as f:
            config_str = f.read()

        # Substitute ${VAR:-default} patterns
        config_str = self._substitute_env_vars(config_str)

        config = yaml.safe_load(config_str)

        # Validate required sections
        self._validate_config(config)

        return config

    def _substitute_env_vars(self, text: str) -> str:
        """
        Replace ${VAR:-default} with environment variable or default value

        Examples:
            ${OLLAMA_BASE_URL:-http://localhost:11434} -> env var or default
            ${OPENAI_API_KEY:-} -> env var or empty string
        """
        pattern = r'\$\{([^}:]+)(?::-)([^}]*)\}'

        def replacer(match):
            var_name = match.group(1)
            default_value = match.group(2)
            value = os.getenv(var_name, default_value)
            return value

        return re.sub(pattern, replacer, text)

    def _validate_config(self, config: Dict[str, Any]) -> None:
        """Validate configuration has required sections"""
        required_sections = ['app', 'llm', 'research']

        for section in required_sections:
            if section not in config:
                raise ValueError(f"Missing required config section: {section}")

    def _load_legacy_config(self) -> Dict[str, Any]:
        """
        Load legacy llm_config.py and convert to new format
        Provides backward compatibility
        """
        try:
            import llm_config as legacy

            llm_type = getattr(legacy, 'LLM_TYPE', 'ollama')

            # Get the appropriate legacy config
            if llm_type == 'ollama':
                legacy_llm_config = getattr(legacy, 'LLM_CONFIG_OLLAMA', {})
            elif llm_type == 'openai':
                legacy_llm_config = getattr(legacy, 'LLM_CONFIG_OPENAI', {})
            elif llm_type == 'anthropic':
                legacy_llm_config = getattr(legacy, 'LLM_CONFIG_ANTHROPIC', {})
            else:
                legacy_llm_config = {}

            # Convert to new format
            config = {
                'app': {
                    'name': 'Automated AI Web Researcher',
                    'log_level': 'INFO',
                    'log_directory': 'logs',
                    'data_directory': 'data'
                },
                'llm': {
                    'provider': llm_type,
                    llm_type: self._convert_legacy_llm_config(legacy_llm_config)
                },
                'research': self._get_default_research_config(),
                'ui': self._get_default_ui_config(),
                'logging': self._get_default_logging_config()
            }

            logger.warning(
                "Using legacy llm_config.py. "
                "Consider migrating to config/config.yaml for full features."
            )

            return config

        except ImportError:
            logger.error("No configuration found - neither config.yaml nor llm_config.py")
            raise FileNotFoundError(
                "Configuration not found. Please create config/config.yaml or llm_config.py"
            )

    def _convert_legacy_llm_config(self, legacy_config: Dict[str, Any]) -> Dict[str, Any]:
        """Convert legacy LLM config to new format"""
        return {
            'base_url': legacy_config.get('base_url', ''),
            'model_name': legacy_config.get('model_name', ''),
            'api_key': legacy_config.get('api_key', ''),
            'temperature': legacy_config.get('temperature', 0.7),
            'top_p': legacy_config.get('top_p', 0.9),
            'n_ctx': legacy_config.get('n_ctx', 55000),
            'max_tokens': legacy_config.get('max_tokens', 4096),
            'stop_sequences': legacy_config.get('stop', [])
        }

    def _get_default_research_config(self) -> Dict[str, Any]:
        """Get default research configuration"""
        return {
            'max_searches_per_cycle': 5,
            'max_focus_areas': 5,
            'document_size_limit_ratio': 0.9,
            'search': {
                'provider': 'duckduckgo',
                'max_results': 10,
                'pages_to_scrape': 2,
                'retry_attempts': 3
            },
            'web_scraping': {
                'timeout': 30,
                'max_retries': 3,
                'rate_limit': 1,
                'user_agent': 'AIResearcher/2.0',
                'respect_robots_txt': False
            }
        }

    def _get_default_ui_config(self) -> Dict[str, Any]:
        """Get default UI configuration"""
        return {
            'enable_colors': True,
            'input_mode': 'curses',
            'progress_indicators': {
                'enabled': True
            }
        }

    def _get_default_logging_config(self) -> Dict[str, Any]:
        """Get default logging configuration"""
        return {
            'file': {
                'enabled': True,
                'level': 'INFO'
            },
            'console': {
                'enabled': False
            }
        }

    def get_llm_config(self) -> Dict[str, Any]:
        """
        Get LLM configuration for the active provider
        Compatible with legacy get_llm_config() function
        """
        if self._config is None:
            self.load()

        provider = self._config['llm']['provider']
        llm_config = self._config['llm'].get(provider, {})

        # Add llm_type for backward compatibility
        llm_config['llm_type'] = provider

        return llm_config

    def get(self, path: str, default: Any = None) -> Any:
        """
        Get configuration value by dot-separated path

        Args:
            path: Dot-separated path (e.g., 'llm.ollama.base_url')
            default: Default value if path not found

        Returns:
            Configuration value or default
        """
        if self._config is None:
            self.load()

        keys = path.split('.')
        value = self._config

        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default

        return value

    def is_legacy_mode(self) -> bool:
        """Check if running in legacy configuration mode"""
        return self._legacy_mode


# Global instance for backward compatibility
_global_config_loader = None


def get_config_loader() -> ConfigLoader:
    """Get global configuration loader instance"""
    global _global_config_loader

    if _global_config_loader is None:
        _global_config_loader = ConfigLoader()

    return _global_config_loader


def get_llm_config() -> Dict[str, Any]:
    """
    Get LLM configuration - backward compatible with legacy function

    This function maintains compatibility with existing code that imports
    from llm_config import get_llm_config
    """
    loader = get_config_loader()
    return loader.get_llm_config()


def load_config() -> Dict[str, Any]:
    """Load full application configuration"""
    loader = get_config_loader()
    return loader.load()


if __name__ == "__main__":
    # Test configuration loading
    logging.basicConfig(level=logging.INFO)

    loader = ConfigLoader()
    config = loader.load()

    print("Configuration loaded successfully!")
    print(f"LLM Provider: {config['llm']['provider']}")
    print(f"Legacy mode: {loader.is_legacy_mode()}")

    llm_config = loader.get_llm_config()
    print(f"LLM Config: {llm_config}")
