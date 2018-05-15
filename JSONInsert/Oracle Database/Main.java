import oracle.jdbc.pool.OracleDataSource;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.*;

public class Main implements Runnable {

    Connection connection;

    public Main(Connection con) {
        this.connection = con;
    }

    public static void main(String[] args) throws Throwable {
        final int workers = Integer.parseInt(System.getenv("SB_SCALE"));
        final int duration = Integer.parseInt(System.getenv("SB_DURATION"));
        System.out.println("Running with "+workers+" worker(s) for "+duration+" second(s)");

        OracleDataSource ods = new OracleDataSource();

        ods.setUser("sb");
        ods.setPassword(System.getenv("SB_DATASTORE_PASSWORD"));
        ods.setURL("jdbc:oracle:thin:@//"+System.getenv("SB_DATASTORE_IP")+":1521/sb.data.sb.oraclevcn.com");

        Properties connectionProperties = new Properties();
        connectionProperties.setProperty("autoCommit", "false");
        connectionProperties.setProperty("oracle.jdbc.fanEnabled", "false");
        ods.setConnectionProperties(connectionProperties);

        ThreadGroup tg = new ThreadGroup("JSONInsert");
        tg.setMaxPriority(Thread.MAX_PRIORITY);
        
        List<Main> threads = new ArrayList<>();
        
        for(int i = 0; i < workers; i++) {
            Connection connection = ods.getConnection();
            new Thread(tg, new Main(connection)).start();
        }
        
        Thread.sleep(duration * 1000L);
        tg.interrupt();
    }

    @Override
    public void run() {
        try {
            PreparedStatement ps = connection.prepareStatement("insert into ANPR_COLLECTION(anprid,collection_time,json_data) values (?,SYSDATE,?)");

            final String json = "{\"ID\": 9999999, \"FirstName\": \"FirstName\", \"LastName\": \"LastName\", \"Nationality\": \"GB\"}";
            final long rowsToInsert = 600000L;
            final long batchsize = 500L;
            final long commitFrequency = 15000L;
            final long start = System.currentTimeMillis();
            for (long i = 0; i < rowsToInsert; ++i) {
                ps.setLong(1, i);
                ps.setString(2, json);
                if (batchsize != -1L) {
                    ps.addBatch();
                } else {
                    ps.executeUpdate();
                }

                if (i % batchsize == 0L) {
                    ps.executeBatch();
                }

                if (i % commitFrequency == 0L) {
                    connection.commit();
                }
            }

            if (batchsize != -1L) {
                ps.executeBatch();
            }

            connection.commit();

            System.out.println((double) rowsToInsert / ((System.currentTimeMillis() - start) / 1000.0) + " msgs/sec");

//        if (doAsync) {
//            connection.createStatement().execute("ALTER SESSION SET COMMIT_WRITE = NOWAIT");
//        }


            ps.close();
            connection.close();
        }
        catch (SQLException sqle) {
            sqle.printStackTrace();
        }
    }
}
