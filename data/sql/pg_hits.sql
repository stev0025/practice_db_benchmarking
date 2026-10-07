-- Postgres gets a 15-column SUBSET of hits (loading all 105 columns of 10M rows is slow
-- and adds nothing to the lesson). The ClickHouse table has all 105 columns, which is
-- actually *unfair to ClickHouse* -- and it still wins. Remember that for the interview.
CREATE TABLE IF NOT EXISTS hits (
    WatchID         BIGINT   NOT NULL,
    EventTime       TIMESTAMP NOT NULL,
    EventDate       DATE     NOT NULL,
    CounterID       INTEGER  NOT NULL,
    UserID          BIGINT   NOT NULL,
    RegionID        INTEGER  NOT NULL,
    OS              SMALLINT NOT NULL,
    IsMobile        SMALLINT NOT NULL,
    ResolutionWidth SMALLINT NOT NULL,
    AdvEngineID     SMALLINT NOT NULL,
    TraficSourceID  SMALLINT NOT NULL,
    SearchPhrase    TEXT     NOT NULL,
    URL             TEXT     NOT NULL,
    Referer         TEXT     NOT NULL,
    Title           TEXT     NOT NULL
);
