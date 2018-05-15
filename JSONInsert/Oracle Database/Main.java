import oracle.jdbc.pool.OracleDataSource;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.*;

public class Main implements Runnable {

    Connection connection;
    PreparedStatement ps;
    long docsInserted;

    public Main(Connection con) {
        this.connection = con;
        this.docsInserted = 0;
        try {
            ps = connection.prepareStatement("insert into ANPR_COLLECTION(anprid,collection_time,json_data) values (?,SYSDATE,?)");
        } catch (SQLException sqle) {
            sqle.printStackTrace();
            ps = null;
        }
    }

    public static void main(String[] args) throws Throwable {
        final int workers = Integer.parseInt(System.getenv("SB_SCALE"));
        final int duration = Integer.parseInt(System.getenv("SB_DURATION"));
        System.out.println("Running with " + workers + " worker(s) for " + duration + " second(s)");

        OracleDataSource ods = new OracleDataSource();

        ods.setUser("sb");
        ods.setPassword(System.getenv("SB_DATASTORE_PASSWORD"));
        ods.setURL("jdbc:oracle:thin:@//" + System.getenv("SB_DATASTORE_IP") + ":1521/sb.data.sb.oraclevcn.com");

        Properties connectionProperties = new Properties();
        connectionProperties.setProperty("autoCommit", "false");
        connectionProperties.setProperty("oracle.jdbc.fanEnabled", "false");
        ods.setConnectionProperties(connectionProperties);

        ThreadGroup tg = new ThreadGroup("JSONInsert");
        tg.setMaxPriority(Thread.MAX_PRIORITY);

        List<Main> threads = new ArrayList<>();

        for (int i = 0; i < workers; i++) {
            Connection connection = ods.getConnection();
            Main m = new Main(connection);
            threads.add(m);
        }

        final long start = System.currentTimeMillis();
        for (Main m : threads) {
            new Thread(tg, m).start();
        }

        Thread.sleep(duration * 1000L);
        tg.interrupt();
        final long end = System.currentTimeMillis();

        long docsInserted = 0;

        for (Main m : threads) {
            docsInserted += m.docsInserted;
        }

        System.out.println("--- RESULTS ---");
        System.out.println("Docs/sec=" + ((double) docsInserted / (end - start) / 1000.0d));
    }

    @Override
    public void run() {
        if (ps == null) return;

        try {
            final String json = "{\"ID\": 9999999, \"FirstName\": \"FirstName\", \"LastName\": \"LastName\", \"Nationality\": \"GB\"}";
            final long batchsize = 500L;
            final long commitFrequency = 15000L;
            boolean running = true;

            for (long docsInserted = 0; running; ++docsInserted) {
                ps.setLong(1, docsInserted);
                ps.setString(2, json);
                if (batchsize != -1L) {
                    ps.addBatch();
                } else {
                    ps.executeUpdate();
                }

                if (docsInserted % batchsize == 0L) {
                    ps.executeBatch();
                }

                if (docsInserted % commitFrequency == 0L) {
                    connection.commit();
                    running = !Thread.interrupted();
                }
            }
                
            if (batchsize != -1L) {
                ps.executeBatch();
            }

            connection.commit();

//            System.out.println((double) rowsToInsert / ((System.currentTimeMillis() - start) / 1000.0) + " msgs/sec");

//        if (doAsync) {
//            connection.createStatement().execute("ALTER SESSION SET COMMIT_WRITE = NOWAIT");
//        }


            ps.close();
            connection.close();
        } catch (SQLException sqle) {
            sqle.printStackTrace();
        }
    }
}
