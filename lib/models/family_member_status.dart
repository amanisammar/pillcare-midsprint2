enum FamilyMemberStatus {
  none,
  pending,
  active,
}

extension FamilyMemberStatusX on FamilyMemberStatus {
  bool get isPending => this == FamilyMemberStatus.pending;
  bool get isActive => this == FamilyMemberStatus.active;
}
