/**
 *  Checks properties from a SQL
 */

module.exports = {

  // return true if the sql query alters table schema in some way
  altersSchema: function (sql) {
    sql = sql.trim();
    return sql.search(/alter\s+[\w\."]+\s+/i) !== -1 ||
      sql.search(/drop\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^vacuum\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^create\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^reindex\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^grant\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^revoke\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^cluster\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^comment\s+on\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^explain\s+[\w\.\"]+/i) !== -1;
  },

  // return true if the sql query alters table data
  altersData: function (sql) {
    return this.altersSchema(sql) ||
      sql.search(/^refresh\s+materialized\s+view\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/^truncate\s+[\w\.\"]+/i) !== -1 ||
      sql.search(/insert\s+into/i) !== -1 ||
      sql.search(/update\s+[\w\.\-"]+\s+.*set/i) !== -1 ||
      sql.search(/delete\s+from/i) !== -1;
  }

};
