"""owner profile update request fields

Revision ID: d1e2f3a4b5c6
Revises: c1d2e3f4a5b6
Create Date: 2026-10-03
"""
from alembic import op
import sqlalchemy as sa

revision = 'd1e2f3a4b5c6'
down_revision = 'c1d2e3f4a5b6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('owner', sa.Column('pending_profile_update', sa.Text(), nullable=True))
    op.add_column('owner', sa.Column('pending_update_submitted_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('owner', 'pending_update_submitted_at')
    op.drop_column('owner', 'pending_profile_update')
