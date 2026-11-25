# Dev6 draft deliverables

Contents:
- `seed/zones_resorts.sql`: root-level team seed for risk zones and resorts.
- `admin/src/components/IncidentTable.tsx`: presentational React component shaped to the Incident schema in `contract/openapi.yaml`.

Important:
- SQL is development/demo data, not production data. `TRUNCATE ... CASCADE` also removes incidents referencing zones/resorts.
- Coordinates are based on the sample coordinate area already present in the repository's Dev1 development seed. They have not been verified against an authoritative beach map.
- The repository inspected so far has no admin/frontend application. The component is therefore a proposed standalone file location and is not integrated or build-tested.
- Confirm the frontend location and coordinate choices with the team before merging.
