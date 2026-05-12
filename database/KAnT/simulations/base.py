"""Abstract base class for all KAnT simulation types."""

from __future__ import annotations

from abc import ABC, abstractmethod

from config.models import SimulationResult


class AbstractSimulation(ABC):
    """Base class that every simulation type must subclass.

    Subclasses receive the domain-specific config object and the list of
    mechanism names at construction time, then must implement :meth:`run`.
    """

    def __init__(self, config, models: list[str]) -> None:
        """
        Parameters
        ----------
        config :
            A :class:`~kant.config.models.ZeroDConfig` or
            :class:`~kant.config.models.FlameConfig` instance.
        models : list[str]
            Ordered list of mechanism base names (e.g. ``['FFCM2', 'GRI30']``).
        """
        self.config = config
        self.models = models

    @abstractmethod
    def run(self) -> SimulationResult:
        """Execute the simulation and return a unified result object."""
