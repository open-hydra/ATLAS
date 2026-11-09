"""CP-custom: a material whose cp becomes negative above 550 K, which GPB refuses naming the temperature."""
from custom_classes import CondensedMaterial

Bad = CondensedMaterial("Bad", cp=lambda T: 1000.0 - 4.0 * (T - 300.0), rho=1000.0)
