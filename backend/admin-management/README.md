# Admin Management Service

Manages admin users and provides statistics aggregation.

## Features

- Admin user management
- Statistics aggregation
- Admin profile CRUD

## Development

```bash
cd backend/admin-management
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8005
```

