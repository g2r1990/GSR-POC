"""sprint4_owner_kyc_fields

Revision ID: a1b2c3d4e5f6
Revises: 9bb830ad942d
Create Date: 2026-10-02 10:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '9bb830ad942d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('owner', sa.Column('gstin', sa.String(15), nullable=True))
    op.add_column('owner', sa.Column('doc_url', sa.String(500), nullable=True))
    op.add_column('owner', sa.Column('rejection_reason', sa.Text(), nullable=True))
    op.add_column('owner', sa.Column('firebase_uid', sa.String(128), nullable=True))
    # make password_hash nullable — Firebase owners won't have a password
    op.alter_column('owner', 'password_hash', nullable=True)


def downgrade() -> None:
    op.drop_column('owner', 'gstin')
    op.drop_column('owner', 'doc_url')
    op.drop_column('owner', 'rejection_reason')
    op.drop_column('owner', 'firebase_uid')
    op.alter_column('owner', 'password_hash', nullable=False)
