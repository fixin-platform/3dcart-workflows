_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createLogger = require "../../../../../core/helper/logger"
createKnex = require "../../../../../core/helper/knex"
createBookshelf = require "../../../../../core/helper/bookshelf"
settings = (require "../../../../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

Binding = require "../../../../../lib/Binding"
DownloadOrders = require "../../../../../lib/Task/ActivityTask/Download/DownloadOrders"
createOrder = require "../../../../../lib/Model/Order"
sample = require "#{process.env.ROOT_DIR}/test/fixtures/SaveOrders/sample.json"

describe "DownloadOrders", ->
  binding = null; knex = null; bookshelf = null; logger = null; Order = null; task = null; # shared between tests

  before (beforeDone) ->
    knex = createKnex settings.knex
    bookshelf = createBookshelf knex
    logger = createLogger settings.logger
    Order = createOrder bookshelf
    Promise.bind(@)
    .then -> knex.raw("SET search_path TO pg_temp")
    .then -> Order.createTable()
    .nodeify beforeDone

  after (teardownDone) ->
    knex.destroy()
    .nodeify teardownDone

  beforeEach ->
    binding = new Binding(
      credential: settings.credentials.bellefit
    )
    task = new DownloadOrders(
      ReadOrders:
        avatarId: "wuXMSggRPPmW4FiE9"
        params:
          datestart: "09/10/2013"
          dateend: "09/15/2013"
      SaveOrders:
        avatarId: "wuXMSggRPPmW4FiE9"
        params: {}
    ,
      input: new stream.PassThrough({objectMode: true})
      output: new stream.PassThrough({objectMode: true})
      binding: binding
      bookshelf: bookshelf
      logger: logger
    )

  it "should run", ->
    @timeout(10000)
    new Promise (resolve, reject) ->
      nock.back "test/fixtures/ReadOrders/run.json", (recordingDone) ->
        task.execute()
        .then ->
          knex(Order::tableName).count("id")
          .then (results) ->
            results[0].count.should.be.equal("306")
        .then ->
          Order.where({InvoiceNumber: 24545}).fetch()
          .then (model) ->
            should.exist(model)
            model.get("BillingFirstName").should.be.equal("Alondra")
        .then resolve
        .catch reject
        .finally recordingDone
