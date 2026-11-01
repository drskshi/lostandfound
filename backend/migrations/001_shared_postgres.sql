-- Shared Lost & Found schema for Supabase Postgres.
-- Mirrors prisma/schema.prisma. Not applied. Do not run against production
-- without approval. Extra columns are ignored by the current website.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE "University" (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  "shortName" TEXT NOT NULL,
  city TEXT NOT NULL,
  domains TEXT NOT NULL,
  accent TEXT NOT NULL DEFAULT '#285DE5',
  "refPrefix" TEXT NOT NULL,
  "centerLat" DOUBLE PRECISION NOT NULL,
  "centerLng" DOUBLE PRECISION NOT NULL,
  zoom INTEGER NOT NULL DEFAULT 16,
  "retentionDays" INTEGER NOT NULL DEFAULT 30,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Location" (
  id TEXT PRIMARY KEY,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  "isCollectionPoint" BOOLEAN NOT NULL DEFAULT false,
  hours TEXT
);
CREATE INDEX "Location_universityId_idx" ON "Location"("universityId");

CREATE TABLE "User" (
  id TEXT PRIMARY KEY,
  "authUserId" UUID UNIQUE,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  "passwordHash" TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('MEMBER', 'STAFF', 'ADMIN')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED')),
  department TEXT,
  bio TEXT NOT NULL DEFAULT '',
  "notificationsOn" BOOLEAN NOT NULL DEFAULT true,
  "emailVerifiedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "User_universityId_idx" ON "User"("universityId");

CREATE TABLE "InstitutionMembership" (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('MEMBER', 'STAFF', 'ADMIN')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED')),
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("userId", "universityId")
);

CREATE TABLE "StaffPermission" (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  permission TEXT NOT NULL,
  UNIQUE ("userId", permission)
);

CREATE TABLE "Session" (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

CREATE TABLE "VerificationCode" (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "codeHash" TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "VerificationCode_userId_idx" ON "VerificationCode"("userId");

CREATE TABLE "Item" (
  id TEXT PRIMARY KEY,
  ref TEXT NOT NULL UNIQUE,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  "authorId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('LOST', 'FOUND')),
  status TEXT NOT NULL DEFAULT 'OPEN'
    CHECK (status IN ('OPEN', 'RESERVED', 'RETURNED', 'RESOLVED', 'CLOSED', 'DISPOSED')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  colour TEXT,
  brand TEXT,
  "locationId" TEXT REFERENCES "Location"(id) ON DELETE SET NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  "locationNote" TEXT,
  "occurredAt" TIMESTAMPTZ NOT NULL,
  sensitive BOOLEAN NOT NULL DEFAULT false,
  custody TEXT,
  "collectionPointId" TEXT REFERENCES "Location"(id) ON DELETE SET NULL,
  "storageRef" TEXT,
  "privateDetails" TEXT,
  "verificationQuestion" TEXT,
  "retainUntil" TIMESTAMPTZ,
  "resolvedAt" TIMESTAMPTZ,
  "disposalMethod" TEXT,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Item_feed_idx" ON "Item"("universityId", type, status, "createdAt");
CREATE INDEX "Item_authorId_idx" ON "Item"("authorId");

CREATE TABLE "ItemPhoto" (
  id TEXT PRIMARY KEY,
  "itemId" TEXT NOT NULL REFERENCES "Item"(id) ON DELETE CASCADE,
  file TEXT NOT NULL,
  "originalFile" TEXT,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  tint TEXT NOT NULL DEFAULT '#e7e5e4',
  position INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX "ItemPhoto_itemId_idx" ON "ItemPhoto"("itemId");

CREATE TABLE "Comment" (
  id TEXT PRIMARY KEY,
  "itemId" TEXT NOT NULL REFERENCES "Item"(id) ON DELETE CASCADE,
  "authorId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'COMMENT',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  hidden BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Comment_itemId_idx" ON "Comment"("itemId");

CREATE TABLE "Claim" (
  id TEXT PRIMARY KEY,
  "itemId" TEXT NOT NULL REFERENCES "Item"(id) ON DELETE CASCADE,
  "claimantId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'NEEDS_INFO', 'APPROVED', 'REJECTED', 'WITHDRAWN', 'COMPLETED')),
  details TEXT NOT NULL,
  answer TEXT,
  "lostWhere" TEXT,
  "proofFile" TEXT,
  "assistScore" INTEGER NOT NULL DEFAULT 0,
  "decisionNote" TEXT,
  "decidedById" TEXT REFERENCES "User"(id) ON DELETE SET NULL,
  "decidedAt" TIMESTAMPTZ,
  "handoverCode" TEXT,
  "handoverCodeHash" TEXT,
  "handoverCodeExpiresAt" TIMESTAMPTZ,
  "completedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("itemId", "claimantId")
);
CREATE INDEX "Claim_claimantId_idx" ON "Claim"("claimantId");
CREATE INDEX "Claim_status_idx" ON "Claim"(status);

CREATE TABLE "ClaimMessage" (
  id TEXT PRIMARY KEY,
  "claimId" TEXT NOT NULL REFERENCES "Claim"(id) ON DELETE CASCADE,
  "authorId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  flagged BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "ClaimMessage_claimId_idx" ON "ClaimMessage"("claimId");

CREATE TABLE "ClaimEvent" (
  id TEXT PRIMARY KEY,
  "claimId" TEXT NOT NULL REFERENCES "Claim"(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  detail TEXT NOT NULL DEFAULT '',
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "ClaimEvent_claimId_idx" ON "ClaimEvent"("claimId");

CREATE TABLE "ItemHandover" (
  id TEXT PRIMARY KEY,
  "claimId" TEXT NOT NULL UNIQUE REFERENCES "Claim"(id) ON DELETE CASCADE,
  "itemId" TEXT NOT NULL UNIQUE REFERENCES "Item"(id) ON DELETE CASCADE,
  "staffId" TEXT NOT NULL REFERENCES "User"(id),
  "redeemedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Notification" (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  href TEXT,
  "readAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Notification_userId_readAt_idx" ON "Notification"("userId", "readAt");

CREATE TABLE "Watch" (
  "userId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "itemId" TEXT NOT NULL REFERENCES "Item"(id) ON DELETE CASCADE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY ("userId", "itemId")
);

CREATE TABLE "Report" (
  id TEXT PRIMARY KEY,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  "reporterId" TEXT NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "itemId" TEXT REFERENCES "Item"(id) ON DELETE CASCADE,
  "commentId" TEXT REFERENCES "Comment"(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACTIONED', 'DISMISSED')),
  "resolvedById" TEXT REFERENCES "User"(id) ON DELETE SET NULL,
  "resolvedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "Report_universityId_status_idx" ON "Report"("universityId", status);

CREATE TABLE "AuditLog" (
  id TEXT PRIMARY KEY,
  "universityId" TEXT NOT NULL REFERENCES "University"(id) ON DELETE CASCADE,
  "actorId" TEXT REFERENCES "User"(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  "targetType" TEXT NOT NULL,
  "targetId" TEXT NOT NULL,
  summary TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX "AuditLog_universityId_createdAt_idx" ON "AuditLog"("universityId", "createdAt");

CREATE TABLE "WaitlistRequest" (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  university TEXT NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION "touch_updated_at"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW."updatedAt" = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER "Item_touch" BEFORE UPDATE ON "Item"
  FOR EACH ROW EXECUTE FUNCTION "touch_updated_at"();
CREATE TRIGGER "Claim_touch" BEFORE UPDATE ON "Claim"
  FOR EACH ROW EXECUTE FUNCTION "touch_updated_at"();

CREATE OR REPLACE FUNCTION "current_app_user"()
RETURNS TABLE (id TEXT, "universityId" TEXT, role TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id, u."universityId", u.role
  FROM "User" u
  WHERE u."authUserId" = auth.uid() AND u.status = 'ACTIVE'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION "current_app_user"() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "current_app_user"() TO authenticated;

CREATE OR REPLACE FUNCTION "approve_claim"(p_claim_id TEXT, p_note TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_staff_id TEXT;
  v_uni TEXT;
  v_role TEXT;
  v_claim "Claim";
  v_item "Item";
  v_bytes BYTEA;
  v_code TEXT;
  v_hash TEXT;
BEGIN
  SELECT c.id, c."universityId", c.role
  INTO v_staff_id, v_uni, v_role
  FROM "current_app_user"() AS c;
  IF v_staff_id IS NULL OR v_role NOT IN ('STAFF', 'ADMIN') THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  SELECT * INTO v_claim FROM "Claim" WHERE id = p_claim_id FOR UPDATE;
  IF v_claim.id IS NULL THEN
    RAISE EXCEPTION 'claim missing';
  END IF;
  IF v_claim.status NOT IN ('PENDING', 'NEEDS_INFO') THEN
    RAISE EXCEPTION 'claim is not waiting for review';
  END IF;

  SELECT * INTO v_item FROM "Item" WHERE id = v_claim."itemId" FOR UPDATE;
  IF v_item."universityId" <> v_uni THEN
    RAISE EXCEPTION 'wrong institution';
  END IF;
  IF v_item.status <> 'OPEN' THEN
    RAISE EXCEPTION 'item is not open';
  END IF;
  IF EXISTS (
    SELECT 1 FROM "Claim"
    WHERE "itemId" = v_item.id AND status IN ('APPROVED', 'COMPLETED')
  ) THEN
    RAISE EXCEPTION 'another claim is already approved';
  END IF;

  v_bytes := gen_random_bytes(3);
  v_code := lpad(
    ((get_byte(v_bytes, 0) * 65536 + get_byte(v_bytes, 1) * 256 + get_byte(v_bytes, 2)) % 1000000)::TEXT,
    6,
    '0'
  );
  v_hash := encode(digest(v_claim.id || ':' || v_code, 'sha256'), 'hex');

  UPDATE "Claim"
  SET status = 'APPROVED',
      "decisionNote" = p_note,
      "decidedById" = v_staff_id,
      "decidedAt" = now(),
      "handoverCode" = NULL,
      "handoverCodeHash" = v_hash,
      "handoverCodeExpiresAt" = now() + interval '7 days'
  WHERE id = v_claim.id;

  UPDATE "Claim"
  SET status = 'REJECTED',
      "decisionNote" = 'Another claim was approved for this item.',
      "decidedById" = v_staff_id,
      "decidedAt" = now()
  WHERE "itemId" = v_item.id
    AND id <> v_claim.id
    AND status IN ('PENDING', 'NEEDS_INFO');

  UPDATE "Item" SET status = 'RESERVED' WHERE id = v_item.id;

  INSERT INTO "ClaimEvent" (id, "claimId", title, detail)
  VALUES (gen_random_uuid()::TEXT, v_claim.id, 'Approved', coalesce(p_note, ''));

  INSERT INTO "AuditLog" (id, "universityId", "actorId", action, "targetType", "targetId", summary)
  VALUES (
    gen_random_uuid()::TEXT,
    v_uni,
    v_staff_id,
    'claim.approve',
    'Claim',
    v_claim.id,
    'Approved a claim and issued a one-time collection code.'
  );

  RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION "redeem_collection_code"(p_claim_id TEXT, p_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_staff_id TEXT;
  v_uni TEXT;
  v_role TEXT;
  v_claim "Claim";
  v_hash TEXT;
BEGIN
  SELECT c.id, c."universityId", c.role
  INTO v_staff_id, v_uni, v_role
  FROM "current_app_user"() AS c;
  IF v_staff_id IS NULL OR v_role NOT IN ('STAFF', 'ADMIN') THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  SELECT * INTO v_claim FROM "Claim" WHERE id = p_claim_id FOR UPDATE;
  IF v_claim.id IS NULL OR v_claim.status <> 'APPROVED' THEN
    RAISE EXCEPTION 'claim is not ready for collection';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM "Item" i
    WHERE i.id = v_claim."itemId" AND i."universityId" = v_uni
  ) THEN
    RAISE EXCEPTION 'wrong institution';
  END IF;
  IF v_claim."handoverCodeExpiresAt" IS NULL OR v_claim."handoverCodeExpiresAt" < now() THEN
    RAISE EXCEPTION 'collection code expired';
  END IF;
  IF EXISTS (SELECT 1 FROM "ItemHandover" WHERE "claimId" = v_claim.id OR "itemId" = v_claim."itemId") THEN
    RAISE EXCEPTION 'collection code already used';
  END IF;

  v_hash := encode(digest(v_claim.id || ':' || p_code, 'sha256'), 'hex');
  IF v_claim."handoverCodeHash" IS DISTINCT FROM v_hash THEN
    RAISE EXCEPTION 'collection code does not match';
  END IF;

  INSERT INTO "ItemHandover" (id, "claimId", "itemId", "staffId")
  VALUES (gen_random_uuid()::TEXT, v_claim.id, v_claim."itemId", v_staff_id);

  UPDATE "Claim"
  SET status = 'COMPLETED', "completedAt" = now(), "handoverCodeHash" = NULL
  WHERE id = v_claim.id;

  UPDATE "Item"
  SET status = 'RETURNED', "resolvedAt" = now()
  WHERE id = v_claim."itemId";

  INSERT INTO "AuditLog" (id, "universityId", "actorId", action, "targetType", "targetId", summary)
  VALUES (
    gen_random_uuid()::TEXT,
    v_uni,
    v_staff_id,
    'claim.handover',
    'Claim',
    v_claim.id,
    'Completed handover with a one-time collection code.'
  );

  RETURN 'completed';
END;
$$;

REVOKE ALL ON FUNCTION "approve_claim"(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION "redeem_collection_code"(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "approve_claim"(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION "redeem_collection_code"(TEXT, TEXT) TO authenticated;

ALTER TABLE "University" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Location" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "InstitutionMembership" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "StaffPermission" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Session" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "VerificationCode" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Item" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ItemPhoto" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Comment" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Claim" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ClaimMessage" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ClaimEvent" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ItemHandover" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Notification" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Watch" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Report" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "AuditLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "WaitlistRequest" ENABLE ROW LEVEL SECURITY;

GRANT SELECT (
  id, ref, "universityId", "authorId", type, status, title, description,
  category, colour, brand, "locationId", lat, lng, "locationNote", "occurredAt",
  sensitive, custody, "collectionPointId", "storageRef", "retainUntil",
  "resolvedAt", "disposalMethod", "createdAt", "updatedAt"
) ON "Item" TO authenticated;

GRANT SELECT (
  id, "itemId", "claimantId", status, details, answer, "lostWhere", "assistScore",
  "decisionNote", "decidedById", "decidedAt", "handoverCodeExpiresAt",
  "completedAt", "createdAt", "updatedAt"
) ON "Claim" TO authenticated;

CREATE POLICY "item_same_institution" ON "Item"
  FOR SELECT TO authenticated
  USING (
    "universityId" = (SELECT "universityId" FROM "current_app_user"())
  );

CREATE POLICY "claim_party_or_staff" ON "Claim"
  FOR SELECT TO authenticated
  USING (
    "claimantId" = (SELECT id FROM "current_app_user"())
    OR EXISTS (
      SELECT 1 FROM "Item" i
      WHERE i.id = "Claim"."itemId"
        AND i."universityId" = (SELECT "universityId" FROM "current_app_user"())
        AND (SELECT role FROM "current_app_user"()) IN ('STAFF', 'ADMIN')
    )
  );

CREATE POLICY "notice_own" ON "Notification"
  FOR SELECT TO authenticated
  USING ("userId" = (SELECT id FROM "current_app_user"()));

REVOKE ALL ON "Session", "VerificationCode", "WaitlistRequest" FROM anon, authenticated;
