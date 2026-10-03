"""offer_type_fields

Revision ID: c1d2e3f4a5b6
Revises: a1b2c3d4e5f6
Create Date: 2026-10-03 10:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'c1d2e3f4a5b6'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('offer', sa.Column(
        'offer_type', sa.String(20), nullable=False, server_default='order'))
    op.add_column('offer', sa.Column(
        'menu_item_id', sa.String(36), nullable=True))
    op.add_column('offer', sa.Column(
        'menu_item_name', sa.String(150), nullable=True))
    op.add_column('offer', sa.Column('buy_qty', sa.Integer(), nullable=True))
    op.add_column('offer', sa.Column('free_qty', sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column('offer', 'offer_type')
    op.drop_column('offer', 'menu_item_id')
    op.drop_column('offer', 'menu_item_name')
    op.drop_column('offer', 'buy_qty')
    op.drop_column('offer', 'free_qty')
