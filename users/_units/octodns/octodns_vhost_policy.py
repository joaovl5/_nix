from logging import getLogger

from octodns.processor.base import BaseProcessor
from octodns.record import Record

log = getLogger("VhostPolicyProcessor")


class VhostPolicyProcessor(BaseProcessor):
    """Split-horizon DNS processor for vhost access policy.

    For pihole targets: passes all records through unchanged.
    For other targets (cloudflare): filters desired records to only
    public_vhosts and rewrites A records to the public relay IP.
    Existing records are filtered to only managed types+names so that
    TXT, MX, NS, etc. are left untouched.
    """

    def __init__(
        self, id, public_vhosts, public_ipv4, managed_record_types=None, **kwargs
    ):
        super().__init__(id, **kwargs)
        self.public_vhosts = set(public_vhosts)
        self.public_ipv4 = public_ipv4
        self.managed_record_types = set(managed_record_types or ["A", "AAAA", "CNAME"])

    def _is_pihole(self, target):
        return "pihole" in target.id.lower()

    def process_source_and_target_zones(self, desired, existing, target):
        if self._is_pihole(target):
            return desired, existing

        # All vhost subdomains from the source zone (excluding bare domain)
        managed_names = {r.name for r in desired.records if r.name != ""}

        log.debug(
            "managed_names=%s public_vhosts=%s",
            managed_names,
            self.public_vhosts,
        )

        # Filter existing: keep only managed-type records with managed names.
        # This hides TXT (_acme-challenge), MX, NS, etc. from the diff.
        for record in list(existing.records):
            if not (
                record._type in self.managed_record_types
                and record.name in managed_names
            ):
                existing.remove_record(record)

        # Filter desired: keep only public vhost records.
        for record in list(desired.records):
            if record.name not in self.public_vhosts:
                desired.remove_record(record)
                continue

            # Rewrite A records to point at the public relay IP.
            if record._type == "A":
                data = record.data
                data["type"] = record._type
                data["value"] = self.public_ipv4
                desired.remove_record(record)
                desired.add_record(
                    Record.new(
                        desired,
                        record.name,
                        data,
                        record.source,
                        lenient=True,
                    ),
                    replace=True,
                )

        return desired, existing
